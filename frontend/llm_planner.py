"""LLM Planner for generating milestones from RTL context."""

import json
import os
from typing import List, Dict, Any, Optional
from .condition_parser import parse_condition, extract_signal_name, extract_instance_path


class LLMPlanner:
    """
    Manages LLM interaction for milestone generation.

    Supports both OpenAI and Anthropic APIs, with a mock mode for testing.
    """

    SYSTEM_PROMPT = """You are an expert Hardware Verification Engineer. Your task is to analyze RTL (Verilog/SystemVerilog) code and generate a sequence of milestones (waypoints) that will guide a symbolic execution engine toward a verification target.

A milestone is a condition that the design should reach during execution. The symbolic execution engine will prioritize paths that reach these milestones.

Rules:
1. Each milestone must reference ONLY signals that exist in the provided RTL code.
2. Milestones should form a logical progression toward the target.
3. Start with reset/initialization conditions.
4. Include intermediate states that must be reached before the target.
5. The final milestone should be the verification target itself.

Output Format: Return a JSON array of milestone objects:
[
  {"step": 1, "description": "Reset state", "condition": "rst == 1"},
  {"step": 2, "description": "Counter initialized", "condition": "cnt == 0"},
  {"step": 3, "description": "Target reached", "condition": "cnt > 10"}
]

IMPORTANT: Only use signal names that appear in the RTL code. Do not invent signal names."""

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

    def __init__(self, api_key: Optional[str] = None, provider: str = "auto", mock: bool = False):
        """
        Initialize the LLM Planner.

        Args:
            api_key: API key for the LLM provider. If None, uses environment variables.
            provider: "openai", "anthropic", or "auto" (detect from key format)
            mock: If True, return hardcoded responses without calling API
        """
        self.mock = mock
        self.api_key = api_key
        self.provider = provider
        self.client = None

        if not mock:
            self._init_client()

    def _init_client(self):
        """Initialize the appropriate LLM client."""
        api_key = self.api_key

        # Try environment variables if no key provided
        if not api_key:
            api_key = os.environ.get("OPENAI_API_KEY") or os.environ.get("ANTHROPIC_API_KEY")

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
            elif provider == "anthropic":
                import anthropic
                self.client = anthropic.Anthropic(api_key=api_key)
        except ImportError as e:
            print(f"[LLMPlanner] Warning: Could not import {provider} library: {e}")
            print("[LLMPlanner] Install with: pip install openai anthropic")

    def _call_openai(self, rtl_context: str, target: str) -> str:
        """Call OpenAI API."""
        user_prompt = f"""RTL Code:
```verilog
{rtl_context}
```

Verification Target: {target}

Generate milestones to reach this target. Return ONLY the JSON array."""

        response = self.client.chat.completions.create(
            model="gpt-4",
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
                signal_path, _, _ = parse_condition(condition)
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
        if self.mock:
            print(f"[LLMPlanner] Mock mode: returning hardcoded milestones for '{target}'")
            # Find matching mock response or use default
            milestones = self.MOCK_RESPONSES.get(target, self.MOCK_RESPONSES["default"])
            return milestones

        if not self.client:
            print("[LLMPlanner] Error: No LLM client initialized. Use --mock or provide API key.")
            return self.MOCK_RESPONSES["default"]

        # Call LLM with retry loop for self-correction
        for attempt in range(max_retries):
            try:
                # Call appropriate API
                if self.provider == "openai":
                    response = self._call_openai(rtl_context, target)
                else:
                    response = self._call_anthropic(rtl_context, target)

                # Parse response
                milestones = self._parse_json_response(response)

                # Validate signals
                errors = self._validate_signals(milestones, known_signals)

                if not errors:
                    print(f"[LLMPlanner] Generated {len(milestones)} milestones (attempt {attempt + 1})")
                    return milestones

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
