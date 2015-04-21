install:
	rm *.gem
	gem build leancloud.gemspec
	sudo gem install --no-wrappers *.gem
