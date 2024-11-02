

lock-rpms:
	rpm-lockfile-prototype --bare rpms.in.yaml

build-dev-libs-image:
	podman build . -f Containerfile.dev-libs --tag localhost/s2i-cs10-dev-libs:latest

pip-compile-runtime-deps: build-dev-libs-image
	podman run --rm --volume .:/src/workspace:Z -w /src/workspace localhost/s2i-cs10-dev-libs:latest \
		sh -c "pip-compile requirements.in -c https://raw.githubusercontent.com/openstack/requirements/refs/heads/master/upper-constraints.txt --generate-hashes --allow-unsafe --output-file=requirements.txt"

add-manual-buildtime-deps:
	echo "calver" >> requirements-build.in && \
	echo "Cython" >> requirements-build.in && \
	echo "docutils" >> requirements-build.in && \
	echo "changelog-chug" >> requirements-build.in && \
	podman run --rm --volume .:/src/workspace:Z -w /src/workspace localhost/s2i-cs10-dev-libs:latest \
		sh -c "pip-compile requirements-build.in --allow-unsafe --generate-hashes --output-file=requirements-build.txt"

pip-compile-buildtime-deps: build-dev-libs-image
	podman run --rm --volume .:/src/workspace:Z -w /src/workspace localhost/s2i-cs10-dev-libs:latest \
		sh -c "pip_find_builddeps requirements.txt --append --only-write-on-update -o requirements-build.in --ignore-errors" ; \

pin-python-deps: build-dev-libs-image pip-compile-runtime-deps pip-compile-buildtime-deps add-manual-buildtime-deps

pull-python-deps:
	rm -rf cachi2-output/ cachi2.env && \
	podman run --rm -it --volume .:/src/workspace:Z -w /src/workspace quay.io/redhat-appstudio/cachi2:latest \
		fetch-deps --source /src/workspace '{"type": "pip", "path": ".", "allow_binary": "false", "requirements_build_files": ["requirements-build.txt"], "requirements_files": ["requirements.txt"]}' && \
	podman run --rm -it --volume .:/src/workspace:Z -w /src/workspace quay.io/redhat-appstudio/cachi2:latest \
		generate-env ./cachi2-output -o ./cachi2.env --for-output-dir /tmp/cachi2-output && \
	podman run --rm -it --volume .:/src/workspace:Z -w /src/workspace quay.io/redhat-appstudio/cachi2:latest \
		inject-files ./cachi2-output --for-output-dir /tmp/cachi2-output
	
install-python-deps: build-dev-libs-image
	podman build . -f Containerfile.install-requirements \
		--volume "$(realpath ./cachi2-output)":/tmp/cachi2-output:Z \
		--volume "$(realpath ./cachi2.env)":/tmp/cachi2.env:Z \
		--network none \
		--tag localhost/install-requirements:latest

validate-python-deps: pin-python-deps pull-python-deps install-python-deps

enter:
	podman run --rm -it \
		--volume "$(realpath ./cachi2-output)":/tmp/cachi2-output:Z \
		--volume "$(realpath ./cachi2.env)":/tmp/cachi2.env:Z \
		--volume .:/src/workspace:Z \
		-w /src/workspace \
		--network none \
		localhost/s2i-cs10-dev-libs:latest

