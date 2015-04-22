SHELL = /bin/sh

install:
	rm -rf ./*.gem
	gem build leancloud.gemspec 2>/dev/null
	sudo gem install --no-wrappers *.gem
