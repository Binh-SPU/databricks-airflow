FROM apache/airflow:3.0.2-python3.11

# Only copy requirements - DAGs are synced via git-sync
COPY ./requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt 
