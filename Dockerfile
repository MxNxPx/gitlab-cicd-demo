# inherit from this "empty base image", see https://hub.docker.com/_/python/
FROM python:3.8.10-alpine3.13
#FROM python:3.4.3

# take some responsibility for this container
#MAINTAINER Aarno Aukia <aarno.aukia@vshn.ch>
LABEL name="flask-hello-world"
LABEL version="1.0"

# directory to install the app inside the container
WORKDIR /usr/src/app

# install python dependencies, this will be cached if the requirements.txt file does not change
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# copy application source code into container
COPY app.py .

# drop root privileges when running the application
USER 1001

# run this command at run-time
CMD [ "python", "app.py" ]

# expose this TCP-port
EXPOSE 8080
