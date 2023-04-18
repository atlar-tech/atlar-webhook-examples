FROM golang:1.20 as build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build ./main.go

FROM scratch
COPY --from=build /src/main /main
ENTRYPOINT ["/main"]
