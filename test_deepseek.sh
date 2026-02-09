#!/bin/bash
# Test script for DeepSeek integration

echo "=== DeepSeek Integration Test ==="
echo ""

# Check if API key is set
if [ -z "$DEEPSEEK_API_KEY" ]; then
    echo "Warning: DEEPSEEK_API_KEY not set. Using mock mode."
    echo ""
    echo "To use real DeepSeek API:"
    echo "  export DEEPSEEK_API_KEY='your-key-here'"
    echo "  ./test_deepseek.sh"
    echo ""

    # Run with mock
    echo "Running with mock LLM..."
    python3 -m main 1 designs/test-designs/test_2.v --sv --auto-plan --mock
else
    echo "DEEPSEEK_API_KEY found. Testing with real API..."
    echo ""

    # Run with DeepSeek
    python3 -m main 1 designs/test-designs/test_2.v --sv --auto-plan \
        --llm-provider deepseek \
        --llm-api-key "$DEEPSEEK_API_KEY"
fi
