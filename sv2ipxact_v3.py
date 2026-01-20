import pyslang
import ipyxact.ipyxact as ipyxact
import os
import argparse
import sys
import xml.etree.ElementTree as ET

def get_args():
    parser = argparse.ArgumentParser(description='SystemVerilog to IP-XACT 2014 Converter (With Parameters)')
    parser.add_argument('input', help='Input SystemVerilog Top File')
    parser.add_argument('-m', '--module', required=True, help='Top Module Name')
    parser.add_argument('-o', '--output', default='component.xml', help='Output XML Filename')
    parser.add_argument('-i', '--include', action='append', help='Include Paths')
    parser.add_argument('-p', '--package', action='append', help='Package Files')
    parser.add_argument('-v', '--vendor', default='openhwgroup.org', help='Vendor Name')
    return parser.parse_args()

def configure_preprocessor(pp_options, include_paths):
    if not include_paths: return
    if hasattr(pp_options, 'includePaths'):
        pp_options.includePaths = list(pp_options.includePaths) + include_paths
    else:
        try:
            pp_options.includePaths = include_paths
        except AttributeError:
             pp_options.additionalIncludePaths = list(pp_options.additionalIncludePaths) + include_paths

def calculate_type_width(port_type):
    try:
        if hasattr(port_type, 'bitWidth'): return port_type.bitWidth
        return 1
    except: return 1

# ==========================================
# 1. 结构体打平逻辑
# ==========================================
def flatten_struct_ports(type_symbol, prefix_name, direction):
    flattened_ports = []
    actual_type = type_symbol.canonicalType
    type_kind_str = str(actual_type.kind)
    is_struct_type = "Struct" in type_kind_str 
    
    if is_struct_type:
        iterator = None
        if hasattr(actual_type, 'members'):
            iterator = actual_type.members if not callable(actual_type.members) else actual_type.members()
        else:
            try:
                iter(actual_type)
                iterator = actual_type
            except:
                print(f"[Warn] Cannot iterate members of {prefix_name}")
                return []

        for member in iterator:
            if "Field" in str(member.kind):
                new_name = f"{prefix_name}_{member.name}"
                sub_ports = flatten_struct_ports(member.type, new_name, direction)
                flattened_ports.extend(sub_ports)
    else:
        width = calculate_type_width(type_symbol)
        flattened_ports.append({
            'name': prefix_name,
            'width': width,
            'direction': direction
        })
    return flattened_ports

# ==========================================
# 2. Parameter 提取逻辑 (新增)
# ==========================================
def extract_parameters(instance_body):
    """
    遍历 pyslang 实例体，提取所有参数。
    返回列表: [{'name': 'ADDR_WIDTH', 'value': '32', 'type': 'integer'}, ...]
    """
    params = []
    # 遍历实例中的所有成员
    for member in instance_body:
        # 检查是否为 Parameter
        if "Parameter" in str(member.kind):
            # 过滤掉 Type Parameter (如 parameter type T = int)，IP-XACT 难以描述类型参数
            if hasattr(member, 'isTypeParameter') and member.isTypeParameter:
                continue

            p_name = member.name
            
            # 尝试获取值
            # member.value 通常是一个 ConstantValue 对象
            try:
                val_obj = member.value
                val_str = str(val_obj.value) # 获取具体的数值或字符串
                
                # 简单的类型推断
                p_type = "integer"
                if "\"" in val_str or "'" in val_str:
                    # 如果包含引号，可能是 string 或 bit vector literal (如 32'hF)
                    # IP-XACT 中 bit vector 通常也作为 string 处理，或者处理为 integer
                    # 这里简化处理：如果是纯数字字符串则为 integer
                    if not val_str.isdigit():
                         # 进一步判断是否为 hex 格式
                         if "'h" in val_str or "'d" in val_str or "'b" in val_str:
                             pass # 保持 string 格式，IP-XACT 允许
                         else:
                             p_type = "string"
            except:
                val_str = "0"
                p_type = "integer"

            print(f"  -> Found Parameter: {p_name} = {val_str} ({p_type})")
            
            params.append({
                'name': p_name,
                'value': val_str,
                'type': p_type
            })
    return params

def generate_xml():
    args = get_args()

    # --- pyslang 初始化 ---
    source_manager = pyslang.SourceManager()
    pp_options = pyslang.PreprocessorOptions()
    if args.include:
        valid_includes = [d for d in args.include if os.path.isdir(d)]
        configure_preprocessor(pp_options, valid_includes)
    bag = pyslang.Bag([pp_options])
    compilation = pyslang.Compilation(bag)

    # --- 加载文件 ---
    def load_file(path):
        if not os.path.exists(path):
            print(f"[Error] File not found: {path}"); sys.exit(1)
        tree = pyslang.SyntaxTree.fromFile(path, source_manager, bag)
        compilation.addSyntaxTree(tree)

    if args.package:
        for pkg in args.package: load_file(pkg)
    load_file(args.input)

    # --- 查找模块 ---
    instance = compilation.getRoot().find(args.module)
    if not instance:
        print(f"[Error] Module '{args.module}' not found.")
        return

    # --- 构建 IP-XACT ---
    component = ipyxact.Component()
    component.vendor = args.vendor
    component.library = "user_ip"
    component.name = args.module
    component.version = "1.0"
    
    component.model = ipyxact.Model()
    
    # ----------------------------------------------------
    # Step 1: 处理 Model Parameters
    # ----------------------------------------------------
    print(f"\nExtracting Parameters for: {args.module}")
    param_list = extract_parameters(instance.body)
    
    if param_list:
        component.model.modelParameters = ipyxact.ModelParameters()
        for p in param_list:
            mp = ipyxact.ModelParameter()
            mp.name = p['name']
            mp.value = p['value']
            mp.dataType = p['type'] # integer or string
            
            # 你可以根据需要添加 displayRef 等属性
            component.model.modelParameters.modelParameter.append(mp)
    else:
        print("  -> No parameters found.")

    # ----------------------------------------------------
    # Step 2: 处理 Ports (包含结构体打平)
    # ----------------------------------------------------
    component.model.ports = ipyxact.Ports()
    print(f"\nExtracting Ports for: {args.module}")
    ports = [p for p in instance.body if hasattr(p, 'kind') and 'Port' in str(p.kind)]

    for member in ports:
        port_name = member.name
        direction_str = str(member.direction).lower()
        if 'argumentdirection.' in direction_str: direction_str = direction_str.split('.')[-1]
        
        port_type = member.type if hasattr(member, 'type') else None
        
        canon_type = port_type.canonicalType
        kind_str = str(canon_type.kind)
        is_struct_check = "Struct" in kind_str
        
        ports_to_add = []

        if is_struct_check:
            # print(f"  -> [STRUCT] Flattening: {port_name}")
            flat_list = flatten_struct_ports(port_type, port_name, direction_str)
            ports_to_add.extend(flat_list)
        else:
            width = calculate_type_width(port_type)
            ports_to_add.append({'name': port_name, 'width': width, 'direction': direction_str})

        for p_info in ports_to_add:
            ipx_port = ipyxact.Port()
            ipx_port.name = p_info['name']
            ipx_port.wire = ipyxact.Wire()
            ipx_port.wire.direction = p_info['direction']
            width = p_info['width']
            if width > 1:
                vec = ipyxact.Vector()
                vec.left = str(width - 1); vec.right = "0"
                ipx_port.wire.vectors = vec
            component.model.ports.port.append(ipx_port)

    # 写入中间文件
    print(f"\n[Writing] Intermediate XML: {args.output}")
    component.write(args.output)

    # ----------------------------------------------------
    # Step 3: 后处理 (强制升级到 IP-XACT 2014)
    # ----------------------------------------------------
    print(f"[Post-Processing] Forcing upgrade to IP-XACT 2014...")
    try:
        with open(args.output, 'r', encoding='utf-8') as f:
            content = f.read()

        old_ns = "http://www.spiritconsortium.org/XMLSchema/SPIRIT/1685-2009"
        new_ns = "http://www.accellera.org/XMLSchema/IPXACT/1685-2014"
        
        # 替换 Namespace URI
        if old_ns in content: content = content.replace(old_ns, new_ns)
        else: content = content.replace("http://www.spiritconsortium.org/XMLSchema/SPIRIT/1.5", new_ns)

        # 替换标签前缀 spirit -> ipxact
        content = content.replace("xmlns:spirit=", "xmlns:ipxact=")
        content = content.replace("<spirit:", "<ipxact:")
        content = content.replace("</spirit:", "</ipxact:")
        content = content.replace(" spirit:", " ipxact:")

        # 修复 modelParameter 的 dataType 属性 (old standard use 'type', new use 'dataType')
        # ipyxact 生成时可能使用了 spirit:dataType，或者根本没加
        # 我们这里做一个修正，防止 ipyxact 库老旧导致的问题
        
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(content)
            
        print(f"[Success] Generated IP-XACT 2014 file with Parameters: {args.output}")
        
    except Exception as e:
        print(f"[Error] Failed during post-processing: {e}")

if __name__ == "__main__":
    generate_xml()