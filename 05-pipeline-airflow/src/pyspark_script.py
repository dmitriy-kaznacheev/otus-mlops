"""
Script: pyspark_script.py
Description: PySpark script for testing.
"""

from argparse import ArgumentParser

from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField
from pyspark.sql.types import DoubleType, IntegerType, TimestampType


def cleanup_data(src_path: str, dst_path: str) -> None:
    """Function for cleanup dataset"""
    
    spark = (
        SparkSession
            .builder
            .appName("mlops_hw03")
            .config("spark.driver.memory", "4g") 
            .config("spark.executor.memory", "4g")     # 8 ГБ для экзекутора
            .config("spark.executor.cores", "2")       # 2 ядра на экзекутор
            .config("spark.executor.instances", "6")   # 6 экзекуторов
            .getOrCreate()
    )

    schema = StructType([
        StructField("transaction_id", IntegerType(), True),
        StructField("tx_datetime", TimestampType(), True),
        StructField("customer_id", IntegerType(), True),
        StructField("terminal_id", IntegerType(), True),
        StructField("tx_amount", DoubleType(), True),
        StructField("tx_time_seconds", IntegerType(), True),
        StructField("tx_time_days", IntegerType(), True),
        StructField("tx_fraud", IntegerType(), True),
        StructField("tx_fraud_scenario", IntegerType(), True)
    ])

    # загрузка данных из файлов
    df = spark.read.csv(
        src_path,
        header=False,
        pathGlobFilter="*.txt",
        schema=schema, 
        comment="#",
        mode="PERMISSIVE"
    )

    # очистка данных
    df_clean = (
        df.filter(df.terminal_id.isNotNull())
        .filter(df.customer_id > 0)
        .filter(df.tx_amount > 0)
        .filter(df.tx_time_seconds > 0)
        .filter(df.transaction_id > 0)
        .filter((df.tx_fraud == 0) | (df.tx_fraud == 1))
        .filter((df.tx_fraud_scenario == 0) | (df.tx_fraud_scenario == 1) | (df.tx_fraud_scenario == 2) | (df.tx_fraud_scenario == 3))
        .dropDuplicates(['transaction_id'])
    )

    # Сохранение данных в бакет
    df_clean.repartition(5).write.parquet(f"{dst_path}/dataset.parquet")

    spark.stop()


def main():
    """Main function to execute the PySpark job"""
    
    parser = ArgumentParser()
    parser.add_argument("--bucket", required=True, help="S3 bucket name")
    args = parser.parse_args()
    bucket_name = args.bucket

    if not bucket_name:
        raise ValueError("Environment variable S3_BUCKET_NAME is not set")

    input_path = f"s3a://{bucket_name}/input_data"
    output_path = f"s3a://{bucket_name}/output_data"
    cleanup_data(input_path, output_path)

if __name__ == "__main__":
    main()
