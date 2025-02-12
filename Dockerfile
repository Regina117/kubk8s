FROM openjdk:11-jre-slim
WORKDIR /opt/geoserver

RUN apt update && apt install -y unzip wget \
    && wget -c -q https://build.geoserver.org/geoserver/2.26.x/geoserver-2.26.x-latest-bin.zip --no-check-certificate 

RUN unzip geoserver-2.26.x-latest-bin.zip && ls -l && mv geoserver-2.26.x/* . && rm -rf geoserver-2.26.x*

EXPOSE 8080
CMD ["java", "-jar", "start.jar"]
