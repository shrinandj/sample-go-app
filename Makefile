SHELL := /bin/bash

build:
	GOOS=linux GOARCH=amd64 GOPRIVATE="github.com/*" GONOSUMDB="github.com/*" go build -o _output/bin/sample-go-app github.com/shrinandj/sample-go-app

docker_ci: docker_test docker_build

docker_test:
	@# clean up previous container to prevent container name conflicts locally
	@docker ps -a -q -f label=${TEST_CTR_LABEL} -f status=exited -f status=dead | xargs -I {} docker rm {}
    # build an image that is capable of running the unit tests and builds the output binary
	docker build \
		--target build \
		--build-arg build=${BUILD_URL} \
		--build-arg GITHUB_INTUIT_TOKEN=${GITHUB_INTUIT_TOKEN} \
		--build-arg GIT_COMMIT=${GIT_COMMIT} \
		-t ${TEST_IMAGE} .
	# run the test image, this allows you to have more control over the unit test / integration test runtime
    # Specifcally, you can:
    # - shell into the container to run tests adhoc or inspect test side effects
    # - connect the container to a network to write tests that can interact with other containers
    # - use all the enviromental control docker run affords you as opposed to docker build
	docker run \
		-e APP_ENV="${APP_ENV}" \
		-l ${TEST_CTR_LABEL} \
		--name ${TEST_CTR} \
		${TEST_IMAGE}
	docker cp ${TEST_CTR}:/go/src/github.com/${GITHUB_PROJECT}/coverage.out coverage.out

docker_build:
	# this can reuse the cached build stage that was created when running tests
	docker build \
		--build-arg build=${BUILD_URL} \
		--build-arg GITHUB_INTUIT_TOKEN=${GITHUB_INTUIT_TOKEN} \
		--build-arg GIT_BRANCH=${GIT_BRANCH} \
		--build-arg GIT_COMMIT=${GIT_COMMIT} \
		-t ${IMAGE_FULL_NAME} .

lint:
	@#If you want to run this step outside of docker, you can install the linter from here:
	@#https://github.com/golangci/golangci-lint#install
	golangci-lint run --fast

test:
	go test -v -race -timeout=180s -coverprofile=coverage.out ./...

coverage:
	go test -coverprofile ./coverage.txt -v ./...
	go tool cover -html=./coverage.txt -o ./cover.html

clean:
	rm -rf _output; rm -rf coverage.txt; rm -rf cover.html
