app.js: app.coffee
	./node_modules/.bin/browserify -t coffeeify app.coffee > app.js
