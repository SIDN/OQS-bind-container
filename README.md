# OQS-bind with Falcon, MAYO and SQISign support, packaged in a container

This repository contains the scripts to build a container with SIDN Labs' [OQS-bind](https://github.com/SIDN/OQS-bind), which is a fork of deSEC's and Jason Goertzen's OQS-bind.
Our fork supports the Falcon-512, MAYO-2 and SQISign-1 post-quantum algorithms.

## Building the image

To build the image, run this (simplified) command:

	podman build -f Dockerfile --tag=pqc-bind-oqs:latest

The tag is an example, just make sure you can find the image again for running the image as container.

## Building for distribution

Be sure to use the correct bind-oqs version and check the patches/ directory for the corresponding patch.

To build the image for distribution, run the following commands:

	podman build --platform linux/amd64,linux/arm64 -f Dockerfile --tag=pqc-bind-oqs:latest
	# podman push

To distribute this container to Github, we do the following steps.
First, Obtain a personal access token

	export CR_PAT=YOUR_TOKEN

And login to Github using this token

	echo $CR_PAT | podman login ghcr.io -u USERNAME --password-stdin
	> Login Succeeded

Then, create a manifest, build the container, and push it, as in this example:

	# First, initialise the manifest
	podman manifest create localhost/oqs-bind-container
	
	# Build the image attaching them to the manifest
	podman build --jobs=4 --platform linux/amd64,linux/arm64  --manifest oqs-bind-container .
	
	# If updating a previous image:
	podman tag localhost/oqs-bind-container ghcr.io/SIDN/oqs-bind-container:latest ghcr.io/SIDN/oqs-bind-container:v2
	podman manifest rm localhost/oqs-bind-container
	
	# Finally publish the manifest
	podman manifest push oqs-bind-container ghcr.io/SIDN/oqs-bind-container:latest ghcr.io/SIDN/oqs-bind-container:v2

