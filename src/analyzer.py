import json
import anthropic


SYSTEM_PROMPT = """You are a senior AWS FinOps engineer and Terraform expert.
You will be given a snapshot of an AWS account's cost data and resource utilization.
Your job is to:
1. Identify the top cost optimization opportunities, ranked by potential savings.
2. For each finding, provide a clear explanation of the problem and impact.
3. Where applicable, provide a concrete Terraform code snippet to implement the fix.
4. Summarize total estimated monthly savings.

Be specific. Use the actual resource IDs and costs from the data provided.
Format your response as a clear, actionable report with sections."""


def analyze(inventory: dict) -> str:
    """Send AWS cost/resource data to Claude and stream back recommendations."""
    client = anthropic.Anthropic()

    user_message = f"""Analyze this AWS account cost and resource data and provide optimization recommendations with Terraform fixes:

```json
{json.dumps(inventory, indent=2)}
```

Provide:
1. Executive summary (total spend, biggest cost drivers)
2. Top 5 optimization findings ranked by savings potential, each with:
   - Finding title
   - Affected resources (IDs)
   - Estimated monthly savings
   - Root cause explanation
   - Terraform snippet to fix it
3. Quick wins (things that can be done in <1 hour)
4. Total estimated monthly savings across all findings
"""

    full_response = []

    with client.messages.stream(
        model="claude-opus-4-6",
        max_tokens=4096,
        thinking={"type": "adaptive"},
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_message}],
    ) as stream:
        for text in stream.text_stream:
            full_response.append(text)
            print(text, end="", flush=True)

    return "".join(full_response)
