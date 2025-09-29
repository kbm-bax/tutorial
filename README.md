# Introduction
This is a tutorial for learning the Data Lake House tech stack to be used for in CQI Redesign. Please follow the instructions to proceed with.

# Software Needed
* Docker Desktop
* Git

# Instructions For Use

* Checkout this repo
* Ensure you have docker desktop running
* go into the tutorial folder and start the tutorial by running `docker compose up --build -d`
* Navigate to localhost:8888 to access the Jupyter notebook, like so:
  <img width="1311" height="942" alt="{248B4005-9FDF-4C47-A172-22E56282F2B0}" src="https://github.com/user-attachments/assets/afeabd2d-9484-45dd-9d24-7745610e71ac" />

* Click on the file upload button to upload the 'notebooks/pipeline_example.ipynb' like so:
  <img width="365" height="352" alt="image" src="https://github.com/user-attachments/assets/186d587f-06e3-4447-acdd-352062c9dc23" />
* Once the notebook file is uploaded, execute the steps one by one and see the outputs to understand the processing.
* Feel free to edit the pipeline defined in 'notebooks/pipeline_example.ipynb' and learn more about the capabilities of  PySpark, Delta, Parquet and Minio tech stack.


# Referrences 
* https://delta.io/pdfs/dldg_databricks.pdf
* https://delta-io.github.io/delta-rs/how-delta-lake-works/architecture-of-delta-table/
* https://delta-docs-incubator.netlify.app/
