/**
 * AWS Lambda handler for Image Processing.
 * 
 * This module provides two functions:
 * - uploadImage: Decodes a base64 image from the event and uploads it to S3.
 * - processImage: Retrieves an image from S3, resizes and converts it using Sharp, 
 *   and uploads the processed image to another S3 bucket.
 */

const AWS = require("aws-sdk");
const sharp = require("sharp");
const s3 = new AWS.S3();

let isColdStart = true; // Used to flag the cold start of the Lambda function

// Handles image upload requests.
module.exports.uploadImage = async (event) => {
  const startTime = Date.now();
  const coldStart = isColdStart;
  isColdStart = false; // Subsequent invocations are warm

  try {
    // Parse image data and filename from request body.
    const { image, fileName } = JSON.parse(event.body);
    if (!image || !fileName) {
      throw new Error("Missing 'image' or 'fileName'");
    }

    // Convert the image from base64 to a buffer and upload it.
    const buffer = Buffer.from(image, "base64");
    await s3.putObject({
      Bucket: "my-new-image-uploads-moaz007",
      Key: fileName,
      Body: buffer,
      ContentType: "image/jpeg",
    }).promise();

    const executionTime = Date.now() - startTime;
    console.log(`uploadImage - Execution time: ${executionTime}ms, Cold start: ${coldStart}`);

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: "Image uploaded successfully!",
        coldStart,
        executionTime,
      }),
    };
  } catch (error) {
    console.error("uploadImage Error:", error.message);
    return {
      statusCode: 500,
      body: JSON.stringify({
        message: "Failed to upload image",
        error: error.message,
        coldStart,
      }),
    };
  }
};

// Handles image processing requests.
module.exports.processImage = async (event) => {
  const startTime = Date.now();
  const coldStart = isColdStart;
  isColdStart = false;

  try {
    // Parse the bucket name and file name from request.
    const { bucketName, fileName } = JSON.parse(event.body);
    if (!bucketName || !fileName) {
      throw new Error("Missing 'bucketName' or 'fileName'");
    }

    // Retrieve the image from S3.
    const imageObject = await s3.getObject({ Bucket: bucketName, Key: fileName }).promise();

    // Process the image: resize to 300x300 and convert to JPEG.
    const processedBuffer = await sharp(imageObject.Body)
      .resize(300, 300)
      .toFormat("jpeg")
      .toBuffer();

    // Upload the processed image to the target S3 bucket.
    const processedKey = `processed-${fileName}`;
    await s3.putObject({
      Bucket: "my-new-image-processed-moaz007",
      Key: processedKey,
      Body: processedBuffer,
      ContentType: "image/jpeg",
    }).promise();

    const executionTime = Date.now() - startTime;
    console.log(`processImage - Execution time: ${executionTime}ms, Cold start: ${coldStart}`);

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: "Image processed successfully!",
        processedKey,
        coldStart,
        executionTime,
      }),
    };
  } catch (error) {
    console.error("processImage Error:", error.message);
    return {
      statusCode: 500,
      body: JSON.stringify({
        message: "Failed to process image",
        error: error.message,
        coldStart,
      }),
    };
  }
};

