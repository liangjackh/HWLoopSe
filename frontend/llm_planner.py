"""LLM Planner for generating milestones from RTL context."""

import json
import time
import os
from typing import List, Dict, Any, Optional
from .condition_parser import (
    parse_condition, parse_compound_condition, get_all_signals,
    extract_signal_name, extract_instance_path
)


class LLMPlanner:
    """
    Manages LLM interaction for milestone generation.

    Supports both OpenAI and Anthropic APIs, with a mock mode for testing.
    """

    SYSTEM_PROMPT = """You are an expert Hardware Verification Engineer specializing in Directed Symbolic Execution.
Your task is to analyze the provided SystemVerilog code and break down the path to a specific Verification Target into a sequence of intermediate **Milestones** (Waypoints).

**Goal:**
The Symbolic Execution Engine will use your milestones to steer the search. If the milestones are too far apart or logically impossible, the engine will fail.

**CRITICAL RULES:**
1.  **Exact Signal Names**: You MUST use the exact signal names found in the source code.
    * If the target is in a submodule, use the hierarchical path (e.g., `u_core.u_alu.result`, NOT just `result`).
    * Do not invent signals (e.g., do not use `fifo_count` if the code says `fifo_cnt`).
2.  **Simple Conditions**: Milestones must be boolean expressions using simple operators:
    * Allowed: `==`, `!=`, `>`, `<`, `>=`, `<=`, `&&`, `||`, `!`.
    * FORBIDDEN: SystemVerilog specific syntax like `@(posedge clk)`, `|->`, `$rose`, `$past`.
3.  **Logical Sequence**: The milestones must represent a feasible execution trace.
    * Step 0 is usually Reset or Initialization.
    * Intermediate steps should bridge the gap (e.g., incrementing a counter, finite state machine transitions).
    * The Final step MUST be the Verification Target itself.
4.  **JSON Output Only**: Return a raw JSON list of objects. Do not wrap in markdown code blocks.

**JSON Format:**
[
  {
    "step": 0,
    "description": "Brief explanation (e.g., System Reset)",
    "condition": "rst_n == 0"
  },
  {
    "step": 1,
    "description": "State machine enters IDLE",
    "condition": "u_ctrl.state == 0"
  },
  ...
]"""

    # Mock responses for testing without API
    MOCK_RESPONSES = {
        "test_1.out > 3": [
            {"step": 1, "description": "Reset active", "condition": "RST == 1"},
            {"step": 2, "description": "Output initialized to zero", "condition": "out == 0"},
            {"step": 3, "description": "First increment", "condition": "out == 1"},
            {"step": 4, "description": "Second increment", "condition": "out == 2"},
            {"step": 5, "description": "Target: output exceeds 3", "condition": "out > 3"},
        ],
        "test_1.out >= 2": [
            {"step": 1, "description": "Reset active", "condition": "RST == 1"},
            {"step": 2, "description": "Output initialized", "condition": "out == 0"},
            {"step": 3, "description": "Target: output reaches 2", "condition": "out >= 2"},
        ],
        "default": [
            {"step": 1, "description": "Initial state", "condition": "RST == 1"},
            {"step": 2, "description": "Post-reset state", "condition": "RST == 0"},
        ],
    }

    def __init__(self, api_key: Optional[str] = None, provider: str = "auto", mock: bool = False, base_url: Optional[str] = None):
        """
        Initialize the LLM Planner.

        Args:
            api_key: API key for the LLM provider. If None, uses environment variables.
            provider: "openai", "anthropic", "deepseek", or "auto" (detect from key format)
            mock: If True, return hardcoded responses without calling API
            base_url: Custom base URL for API (e.g., for DeepSeek or other OpenAI-compatible APIs)
        """
        self.mock = mock
        self.api_key = api_key
        self.provider = provider
        self.base_url = base_url
        self.client = None

        if not mock:
            self._init_client()

    def _init_client(self):
        """Initialize the appropriate LLM client."""
        api_key = self.api_key

        # Try environment variables if no key provided
        if not api_key:
            api_key = os.environ.get("OPENAI_API_KEY") or os.environ.get("ANTHROPIC_API_KEY") or os.environ.get("DEEPSEEK_API_KEY")

        if not api_key:
            print("[LLMPlanner] Warning: No API key provided. Use --mock for testing.")
            return

        # Auto-detect provider from key format
        provider = self.provider
        if provider == "auto":
            if api_key.startswith("sk-ant-"):
                provider = "anthropic"
            elif api_key.startswith("sk-"):
                provider = "openai"
            else:
                print(f"[LLMPlanner] Warning: Cannot detect provider from key format. Defaulting to openai.")
                provider = "openai"

        self.provider = provider

        try:
            if provider == "openai":
                from openai import OpenAI
                self.client = OpenAI(api_key=api_key)
            elif provider == "deepseek":
                from openai import OpenAI
                # DeepSeek uses OpenAI-compatible API
                base_url = self.base_url or "https://api.deepseek.com"
                self.client = OpenAI(api_key=api_key, base_url=base_url)
                print(f"[LLMPlanner] Using DeepSeek API at {base_url}")
            elif provider == "anthropic":
                import anthropic
                self.client = anthropic.Anthropic(api_key=api_key)
        except ImportError as e:
            print(f"[LLMPlanner] Warning: Could not import {provider} library: {e}")
            print("[LLMPlanner] Install with: pip install openai anthropic")

    def _call_openai(self, rtl_context: str, target: str) -> str:
        """Call OpenAI API (or OpenAI-compatible APIs like DeepSeek)."""
        user_prompt = f"""RTL Code:
```verilog
{rtl_context}
```

Verification Target: {target}

Generate milestones to reach this target. Return ONLY the JSON array."""

        # Choose model based on provider
        if self.provider == "deepseek":
            model = "deepseek-chat"  # DeepSeek's chat model
        else:
            model = "gpt-4"  # OpenAI default

        response = self.client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": self.SYSTEM_PROMPT},
                {"role": "user", "content": user_prompt}
            ],
            temperature=0.2,
        )
        return response.choices[0].message.content

    def _call_anthropic(self, rtl_context: str, target: str) -> str:
        """Call Anthropic API."""
        user_prompt = f"""RTL Code:
```verilog
{rtl_context}
```

Verification Target: {target}

Generate milestones to reach this target. Return ONLY the JSON array."""

        response = self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=1024,
            system=self.SYSTEM_PROMPT,
            messages=[
                {"role": "user", "content": user_prompt}
            ],
        )
        return response.content[0].text

    def _parse_json_response(self, response: str) -> List[Dict[str, Any]]:
        """Parse JSON from LLM response, handling markdown code blocks."""
        # Strip markdown code blocks if present
        response = response.strip()
        if response.startswith("```json"):
            response = response[7:]
        elif response.startswith("```"):
            response = response[3:]
        if response.endswith("```"):
            response = response[:-3]

        return json.loads(response.strip())

    def _validate_signals(self, milestones: List[Dict], known_signals: List[str]) -> List[str]:
        """
        Validate that all signals in milestones exist in known_signals.

        Args:
            milestones: List of milestone dictionaries
            known_signals: List of valid signal names

        Returns:
            List of error messages for invalid signals (empty if all valid)
        """
        errors = []
        known_set = set(known_signals)

        # Also create a lowercase mapping for fuzzy matching
        known_lower = {s.lower(): s for s in known_signals}

        for m in milestones:
            condition = m.get("condition", "")
            try:
                # Use compound condition parser to handle &&, ||, !
                parsed = parse_compound_condition(condition)
                signal_paths = get_all_signals(parsed)

                for signal_path in signal_paths:
                    signal_name = extract_signal_name(signal_path)

                    # Check if signal exists
                    if signal_name not in known_set:
                        # Try case-insensitive match
                        if signal_name.lower() in known_lower:
                            suggestion = known_lower[signal_name.lower()]
                            errors.append(f"Signal '{signal_name}' not found. Did you mean '{suggestion}'?")
                        else:
                            # Find similar signals
                            similar = [s for s in known_signals if signal_name.lower() in s.lower() or s.lower() in signal_name.lower()]
                            if similar:
                                errors.append(f"Signal '{signal_name}' not found. Similar signals: {similar[:3]}")
                            else:
                                errors.append(f"Signal '{signal_name}' not found in design.")
            except ValueError as e:
                errors.append(f"Cannot parse condition '{condition}': {e}")

        return errors

    def generate_plan(
        self,
        rtl_context: str,
        target: str,
        known_signals: List[str],
        max_retries: int = 3
    ) -> List[Dict[str, Any]]:
        """
        Generate milestones for a verification target.

        Args:
            rtl_context: The sliced RTL source code
            target: The verification target expression
            known_signals: List of valid signal names for validation
            max_retries: Maximum retry attempts for self-correction

        Returns:
            List of milestone dictionaries with 'step', 'description', 'condition'
        """
        print(f"[LLMPlanner] context: {rtl_context[:200]}... (truncated), target: {target}, known_signals: {known_signals[:10]}... (truncated)")

        if self.mock:
            print(f"[LLMPlanner] Mock mode: returning hardcoded milestones for '{target}'")

            # Extract module name from target (e.g., "place_holder.out > 2" -> "place_holder")
            module_name = None
            if '.' in target:
                module_name = target.split('.')[0]

            # Find matching mock response or use default
            milestones = self.MOCK_RESPONSES.get(target, self.MOCK_RESPONSES["default"])

            # If we have a module name, prefix signal names in conditions
            if module_name:
                milestones = []
                base_milestones = self.MOCK_RESPONSES.get(target, self.MOCK_RESPONSES["default"])
                for m in base_milestones:
                    milestone = m.copy()
                    condition = milestone['condition']

                    # Add module prefix to signal names that don't already have one
                    # Simple heuristic: if condition contains a signal name without '.', prefix it
                    if '.' not in condition:
                        # Extract signal name (first word before operator)
                        import re
                        match = re.match(r'(\w+)\s*([<>=!]+)', condition)
                        if match:
                            signal = match.group(1)
                            # Prefix with module name
                            condition = condition.replace(signal, f"{module_name}.{signal}", 1)
                            milestone['condition'] = condition

                    milestones.append(milestone)

            return milestones

        if not self.client:
            print("[LLMPlanner] Error: No LLM client initialized. Use --mock or provide API key.")
            return self.MOCK_RESPONSES["default"]

        # Call LLM with retry loop for self-correction
        for attempt in range(max_retries):
            try:
                # Call appropriate API
                if self.provider in ["openai", "deepseek"]:
                    response = self._call_openai(rtl_context, target)
                else:
                    response = self._call_anthropic(rtl_context, target)

                # Parse response
                print(f"[LLMPlanner] LLM response: {response}... (truncated)")
                milestones = self._parse_json_response(response)

                # Validate signals
                print(f"[LLMPlanner] known signals: {known_signals}")
                errors = self._validate_signals(milestones, known_signals)

                if not errors:
                    print(f"[LLMPlanner ]Successfully generated {len(milestones)} milestones (attempt {attempt + 1})")
                    time.sleep(5)
                    return milestones

                time.sleep(5)
                # Self-correction: feed errors back to LLM
                print(f"[LLMPlanner] Validation errors (attempt {attempt + 1}): {errors}")

                if attempt < max_retries - 1:
                    # Modify context to include error feedback
                    error_feedback = "\n".join(errors)
                    rtl_context = f"{rtl_context}\n\n[VALIDATION ERROR - Please correct]\n{error_feedback}"

            except json.JSONDecodeError as e:
                print(f"[LLMPlanner] JSON parse error (attempt {attempt + 1}): {e}")
            except Exception as e:
                print(f"[LLMPlanner] API error (attempt {attempt + 1}): {e}")

        # Fallback to default milestones
        print("[LLMPlanner] Warning: All attempts failed, using default milestones")
        return self.MOCK_RESPONSES["default"]
