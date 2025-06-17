# Инфраструктура с модулями для Yandex.Cloud

Эта директория содержит код Terraform для создания инфраструктуры проекта. 
Инфраструктура разделена на модули, для более гибкого управления:

* [модуль airflow-cluster](modules/airflow-cluster)
* [модуль compute](modules/compute)
* [модуль iam](modules/iam)
* [модуль network](modules/network)
* [модуль storage](modules/storage)
