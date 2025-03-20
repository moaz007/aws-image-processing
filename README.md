# Serverless Image Processing API

This project is a serverless image processing API built with Node.js (v20.19.0) using the AWS CLI and the Serverless Framework. It leverages AWS Lambda for executing functions, along with GitHub Actions for automated continuous integration and deployment.

The API accepts a base64-encoded image and file name in a JSON payload, processes the image (resizes it to 300×300 pixels and converts it to JPEG), and stores the resulting image in designated storage buckets.

This repository contains all the necessary configurations and scripts for deploying the project on AWS, and demonstrates a modern, automated CI/CD workflow.

