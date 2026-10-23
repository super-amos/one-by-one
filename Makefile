.PHONY: build test app run install icon clean

build:
	swift build

test:
	swift test

app:
	scripts/bundle.sh

run: app
	open "build/One by One.app"

install: app
	rm -rf "/Applications/One by One.app"
	ditto "build/One by One.app" "/Applications/One by One.app"

icon:
	swift scripts/make-icon.swift build/AppIcon.iconset
	mkdir -p Resources
	iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns

clean:
	rm -rf .build build
