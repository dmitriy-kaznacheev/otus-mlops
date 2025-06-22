include .env

S3_CMD=s3cmd --access_key=${S3_ACCESS_KEY} --secret_key=${S3_SECRET_KEY} -s --host-bucket="%(bucket)s.storage.yandexcloud.net"

upload_all: upload_src upload_dags upload_data

upload_dags:
	$(info Uploading dags to $(S3_BUCKET_NAME)...)
	$(S3_CMD) put --recursive dags/ s3://$(S3_BUCKET_NAME)/dags/
	$(info DAGs uploaded successfully)

upload_src:
	$(info Uploading src to $(S3_BUCKET_NAME)...)
	$(S3_CMD) put --recursive src/ s3://$(S3_BUCKET_NAME)/src/
	$(info src uploaded successfully)

upload_data:
	$(info Uploading data to $(S3_BUCKET_NAME)...)
	$(S3_CMD) --acl-public -r sync s3://otus-mlops-source-data/ s3://$(S3_BUCKET_NAME)/input_data/
	$(info Data uploaded successfully)

airflow_mon:
	yc logging read --group-name=default --follow

git_push_secrets:
	$(info Pushing secrets to github...)
	python3 utils/push_secrets_to_github_repo.py
