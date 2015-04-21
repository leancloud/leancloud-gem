install:
	gem build leancloud.gemspec
	sudo gem install --no-wrappers leancloud-0.0.1.gem
