#!/bin/sh

#
# htb -- spit out simple HTML-sample.
#


title="$1"

echo "<!doctype html>
<html lang="en">
<head>
	<meta charset="UTF-8" >
	<meta name="viewport" content="width=device-width, initial-scale=1.0" >
	<link rel="shortcut icon" href="#">
	<title>$title</title>
</head>
<body>
</body>
</html>"
