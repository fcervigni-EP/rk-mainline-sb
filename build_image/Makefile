IMAGE_NAME = ec942-flash-builder

.PHONY: all clean

all: .built

.built: Dockerfile
	docker build -t $(IMAGE_NAME) .
	touch .built

clean:
	docker rmi $(IMAGE_NAME) 2>/dev/null || true
	rm -f .built

