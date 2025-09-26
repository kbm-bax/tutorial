FROM jupyter/pyspark-notebook:latest

USER root

# Install Python package for delta-spark
RUN pip install delta-spark==3.2.0

# Install libraries for S3A filesystem to connect with MinIO
# These are needed by Spark, even when specified in PYSPARK_SUBMIT_ARGS, for local operations
RUN wget https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar --no-check-certificate -O /usr/local/spark/jars/hadoop-aws-3.3.4.jar
RUN wget https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar --no-check-certificate -O /usr/local/spark/jars/aws-java-sdk-bundle-1.12.262.jar

USER $NB_USER
