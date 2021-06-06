FROM golang:alpine as builder

ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

WORKDIR /build
COPY go.mod /build
COPY go.sum /build
COPY redis-tls-updater.go /build
#RUN go build -ldflags "-linkmode external -extldflags -static" -a main.go
RUN go build -ldflags '-extldflags -static' -a redis-tls-updater.go
RUN pwd
RUN ls

FROM scratch
COPY --from=builder /build/redis-tls-updater /app/
CMD ["/app/redis-tls-updater"]
