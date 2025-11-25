# Introduction
This is a tutorial for learning the Data Lake House tech stack to be used for in CQI Redesign. This tutorial includes:
* **PySpark** - Data processing engine
* **Delta Lake** - ACID transactions and time travel for data lakes
* **MinIO** - S3-compatible object storage
* **Dremio** - SQL query engine for analytics

Please follow the instructions to proceed with.

# Software Needed
* Docker Desktop
* Git

# Instructions For Use

* Checkout this repo
* Ensure you have docker desktop running
* go into the tutorial folder and start the tutorial by running `docker compose up --build -d` . This command will take 5-10 mins (based on your Internet speed) to complete for the first time as it will downloads all the container images needed to run the tutorial.
* **NEW:** Dremio will be automatically configured with MinIO as a data source. Default credentials: `admin` / `admin123`
* Navigate to http://localhost:8888 to access the Jupyter notebook, like so (there is no authentication/authorization needed) :
  <img width="1311" height="942" alt="{248B4005-9FDF-4C47-A172-22E56282F2B0}" src="https://github.com/user-attachments/assets/afeabd2d-9484-45dd-9d24-7745610e71ac" />

* Click on the file upload button to upload the 'notebooks/pipeline_example.ipynb' like so:
  <img width="365" height="352" alt="image" src="https://github.com/user-attachments/assets/186d587f-06e3-4447-acdd-352062c9dc23" />
* Once the notebook file is uploaded, execute the steps one by one and see the outputs to understand the processing.
* Once the pipeline is executed, you can view the data you created in the Minio web console at http://localhost:9011 (username: minio password: password)
* After logging into the Minio Web Console, navigate the various buckets under the datalakehouse/deltalake path. Navigate to each of the 3 layers (Bronze, Silver and Gold) to see the Delta and Parquet tables that got created, like so:
  <img width="1920" height="1140" alt="{A6EFC562-E6F9-43DF-BB8B-8510BB75A4E7}" src="https://github.com/user-attachments/assets/87188d6a-8f85-4e7f-ae4b-2f78691b9918" />

* Feel free to edit the pipeline defined in 'notebooks/pipeline_example.ipynb' and learn more about the capabilities of  PySpark, Delta, Parquet and Minio tech stack.
* **NEW: Query with Dremio** - Access Dremio at http://localhost:9047 to query the Delta Lake tables using SQL. See [DREMIO_SETUP_GUIDE.md](DREMIO_SETUP_GUIDE.md) for detailed setup instructions.
* To shutdown the setup, execute `docker compose down`.

# Common Troubleshooting steps
* Incase you face any port conflicts, make sure you change the respective conflicting ports in the docker-compose.yaml and relaunch the setup.


# Documentation

* 🚀 **[QUICK_START.md](QUICK_START.md)** - Get started in 5 minutes
* 📖 **[DREMIO_SETUP_GUIDE.md](DREMIO_SETUP_GUIDE.md)** - Detailed Dremio configuration and usage
* 🔧 **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions
* 🏗️ **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture and design
* 💻 **[notebooks/dremio_queries.sql](notebooks/dremio_queries.sql)** - SQL query examples

# References 
* https://delta.io/pdfs/dldg_databricks.pdf
* https://delta-io.github.io/delta-rs/how-delta-lake-works/architecture-of-delta-table/
* https://delta-docs-incubator.netlify.app/
* https://docs.dremio.com/
