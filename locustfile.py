# Copyright (c) 2025 Andrey Chuyan (oksigen077777@gmail.com)
# locustfile.py

import os
from dotenv import load_dotenv
from locust import HttpUser, task, between

load_dotenv()

endpoints = os.getenv("ENDPOINTS", "/").split(",")
weights = [int(x) for x in os.getenv("ENDPOINTS_WEIGHTS", "1").split(",")]

def make_task(path):
    def task_func(self):
        self.client.get(path)
    return task_func

task_list = []
for path, weight in zip(endpoints, weights):
    task_list.extend([make_task(path)] * weight)

class WebsiteUser(HttpUser):
    wait_time = between(1, 3)
    tasks = task_list