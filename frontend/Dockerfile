
FROM debian:stable-slim AS build-env

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ARG FLUTTER_VERSION=3.19.6
RUN git clone https://github.com/flutter/flutter.git -b ${FLUTTER_VERSION} /usr/local/flutter

ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

RUN flutter doctor -v
RUN flutter config --enable-web

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release

FROM nginx:alpine

COPY --from=build-env /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]