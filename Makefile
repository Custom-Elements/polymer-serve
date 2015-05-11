docs:
	echo '```' > README.md
	./bin/polymer-serve --help >> README.md
	echo '```' >> README.md
