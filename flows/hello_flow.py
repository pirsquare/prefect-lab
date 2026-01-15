"""
Example Prefect flow demonstrating:
- Schedule-based triggering
- Automatic retries
- Structured logging
- Task dependencies
"""

from datetime import datetime
import logging
from prefect import flow, task
from prefect.logging import get_run_logger


# Task 1: Validate inputs
@task(retries=2, retry_delay_seconds=5)
def fetch_data(data_source: str) -> dict:
    """Simulate fetching data from a source with retry logic."""
    logger = get_run_logger()
    logger.info(f"Fetching data from {data_source}")
    
    # Simulate occasional failures (will retry up to 2 times)
    import random
    if random.random() < 0.2:  # 20% chance of failure
        raise ValueError(f"Failed to fetch from {data_source}")
    
    return {
        "timestamp": datetime.now().isoformat(),
        "source": data_source,
        "records": 42
    }


# Task 2: Process the data
@task
def process_data(raw_data: dict) -> dict:
    """Transform and validate the fetched data."""
    logger = get_run_logger()
    logger.info(f"Processing {raw_data['records']} records from {raw_data['source']}")
    
    processed = {
        "count": raw_data["records"],
        "status": "processed",
        "timestamp": raw_data["timestamp"]
    }
    logger.info(f"Processed data: {processed}")
    return processed


# Task 3: Store result
@task
def store_result(processed_data: dict) -> str:
    """Store processed data (simulated)."""
    logger = get_run_logger()
    run_id = datetime.now().strftime("%Y%m%d_%H%M%S")
    logger.info(f"Storing result {run_id}: {processed_data}")
    return run_id


# Main Flow
@flow(
    name="hello-flow",
    description="Example ETL flow with retries and logging"
)
def hello_flow(data_source: str = "api.example.com") -> str:
    """
    Main orchestration flow.
    
    Args:
        data_source: Source to fetch data from
        
    Returns:
        Result ID for tracking
    """
    logger = get_run_logger()
    logger.info(f"Starting hello_flow with source: {data_source}")
    
    raw_data = fetch_data(data_source)
    processed_data = process_data(raw_data)
    result_id = store_result(processed_data)
    
    logger.info(f"Flow completed successfully. Result ID: {result_id}")
    return result_id


if __name__ == "__main__":
    # For local testing via `python flows/hello_flow.py`
    result = hello_flow()
    print(f"Flow execution result: {result}")
