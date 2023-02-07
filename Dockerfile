FROM python:3.10
ADD requirements.txt .
RUN pip install -r requirements.txt
RUN apt update && apt install -y jq && rm -rf /var/lib/apt/lists/*
ADD google_ads_queries/ google_ads_queries/
ADD bq_queries/ bq_queries/
ADD scripts/ scripts/
ADD run.sh .
RUN chmod a+x run.sh
CMD bash ./run.sh
