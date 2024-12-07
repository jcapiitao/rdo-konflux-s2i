lock-rpms:
	rpm-lockfile-prototype --bare rpms.in.yaml

build-dev-libs-image:
	podman build . \
		--file Containerfile.dev-libs \
		--volume "$(realpath ./rpms.in.yaml)":/tmp/rpms.in.yaml:Z \
		--volume "$(realpath ./cachi2.env)":/tmp/cachi2.env:Z \
		--tag localhost/s2i-cs10-dev-libs:latest

run-dev-libs-image: build-dev-libs-image
	podman run --rm -it \
		--volume "$(realpath ./cachi2-output)":/tmp/cachi2-output:Z \
		--volume "$(realpath ./cachi2.env)":/tmp/cachi2.env:Z \
		--volume s2i-cs10-dev-libs-cache:/tmp/cache:Z \
		--volume .:/src/workspace:Z \
		-w /src/workspace \
		localhost/s2i-cs10-dev-libs:latest
	        # FIXME: remove network once hermetic build reenabled
		# https://github.com/jcapiitao/rdo-konflux-s2i/issues/26
		#--network none \

pip-compile-runtime-deps: build-dev-libs-image
	podman run --rm --volume .:/src/workspace:Z -w /src/workspace localhost/s2i-cs10-dev-libs:latest \
		sh -c "pip-compile requirements.in -c https://raw.githubusercontent.com/openstack/requirements/refs/heads/master/upper-constraints.txt --generate-hashes --allow-unsafe --output-file=requirements.txt"

pip-compile-buildtime-deps: build-dev-libs-image
	> requirements-build-added-manually.in && \
	echo "calver" >> requirements-build-added-manually.in && \
	echo "Cython" >> requirements-build-added-manually.in && \
	echo "docutils" >> requirements-build-added-manually.in && \
	echo "changelog-chug" >> requirements-build-added-manually.in && \
	echo "yq" >> requirements-build-added-manually.in && \
	podman run --rm --volume .:/src/workspace:Z -w /src/workspace localhost/s2i-cs10-dev-libs:latest \
		sh -c "pip-compile requirements-build.in requirements-build-added-manually.in -c https://raw.githubusercontent.com/openstack/requirements/refs/heads/master/upper-constraints.txt --allow-unsafe --generate-hashes --output-file=requirements-build.txt"

pip-find-buildtime-deps: build-dev-libs-image
	podman run --rm --volume .:/src/workspace:Z -w /src/workspace localhost/s2i-cs10-dev-libs:latest \
		sh -c "pip_find_builddeps requirements.txt --append --only-write-on-update -o requirements-build.in --ignore-errors" ; \

pin-python-deps: build-dev-libs-image pip-compile-runtime-deps pip-find-buildtime-deps pip-compile-buildtime-deps

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
