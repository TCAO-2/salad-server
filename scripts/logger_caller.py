# Call the main logger from python scripts.

import os
import subprocess
import threading





LOG_LEVELS = ["TRACE", "VERB", "INFO", "WARN", "ERROR"]

LOG_LEVEL_CONSOLE = os.environ.get("LOG_LEVEL_CONSOLE", "INFO")
LOG_LEVEL_FILE = os.environ.get("LOG_LEVEL_FILE", "INFO")

LEAST_LOG_LEVEL_IDX = min(
    LOG_LEVELS.index(LOG_LEVEL_CONSOLE),
    LOG_LEVELS.index(LOG_LEVEL_FILE)
)

def logger(log_message, log_level):
    """Asynchronous logger to less slow the main program when spamming it."""
    def log_task():
        try:
            # Do not call the logger if the least log level is not reached.
            if (LOG_LEVELS.index(log_level) >= LEAST_LOG_LEVEL_IDX):
                subprocess.run(
                    [
                        "/bin/bash",
                        "/opt/salad-server/scripts/logger.sh",
                        "check-data-integrity",
                        log_message,
                        log_level
                    ],
                    check=True,
                )
        except subprocess.CalledProcessError as e:
            print(f"Logging failed: {e}")
    thread = threading.Thread(target=log_task)
    thread.start()
