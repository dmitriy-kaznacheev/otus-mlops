# Настройка облачной инфраструктуры для проекта по определению мошеннических транзакций


## Цель работы
Знакомство с облачным провайдером Yandex Cloud: 
  * работа с сервисами [Object Storage](#yandex-object-storage) и [Data Processing](#yandex-data-processing)
  * создание Spark-кластера и копирование в него данных 
  * изучение оценки затрат при проектировании облачной инфраструктуры


## Сервисы
### Yandex Object Storage
Универсальное масштабируемое S3-хранилище

### Yandex Data Processing
Сервис для обработки многотерабайтных массивов данных 
с использованием инструментов с открытым исходным кодом, 
таких как Apache Spark™, Apache Hadoop®, Apache HBase®, Apache Zeppelin™ 
и других сервисов экосистемы Apache®.


## Задачи:
  1. cоздан новый backet в *Yandex Cloud Object Storage* с использованием *terraform* скрипта
