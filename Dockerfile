FROM openjdk:11-jre-slim
WORKDIR /opt/geoserver

# Устанавливаем необходимые пакеты
RUN apt update && apt install -y unzip wget && rm -rf /var/lib/apt/lists/*

# Скачиваем GeoServer
RUN wget -c -q https://build.geoserver.org/geoserver/2.26.x/geoserver-2.26.x-latest-bin.zip --no-check-certificate

# Распаковываем (файлы появляются прямо в /opt/geoserver, без отдельной папки)
RUN unzip geoserver-2.26.x-latest-bin.zip && rm geoserver-2.26.x-latest-bin.zip

# Проверяем содержимое
RUN ls -l

# Даем права на запуск для startup.sh
RUN chmod +x ./bin/startup.sh

# Даем права на запись в директорию данных
RUN chmod -R 777 /opt/geoserver/data_dir

EXPOSE 8080
CMD ["./bin/startup.sh"]
