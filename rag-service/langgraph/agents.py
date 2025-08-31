from langchain_core.tools import tool
import random
from datetime import datetime

@tool
def get_current_time() -> str:
    """Get the current date and time."""
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

@tool
def generate_random_number(min_val: int = 1, max_val: int = 100) -> int:
    """Generate a random number between min_val and max_val (inclusive)."""
    return random.randint(min_val, max_val)

@tool
def calculate_sum(a: float, b: float) -> float:
    """Calculate the sum of two numbers."""
    return a + b

@tool
def customer_support_info(topic: str) -> str:
    """Get basic customer support information for common topics."""
    support_info = {
        "billing": "For billing inquiries, please contact our billing department at billing@company.com or call 1-800-BILLING.",
        "technical": "For technical support, please visit our help center at help.company.com or contact tech@company.com.",
        "returns": "Returns are accepted within 30 days of purchase. Please visit returns.company.com to initiate a return.",
        "shipping": "Standard shipping takes 5-7 business days. Express shipping takes 2-3 business days.",
        "account": "To manage your account, log in to account.company.com or contact support@company.com."
    }
    
    topic_lower = topic.lower()
    for key, value in support_info.items():
        if key in topic_lower:
            return value
    
    return "For general support, please contact support@company.com or call 1-800-SUPPORT."

# Export all tools for testing
X = [get_current_time, generate_random_number, calculate_sum, customer_support_info]