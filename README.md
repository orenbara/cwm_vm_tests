inside "advanced installation" block:

* If you want that this code won't crush the installation if it fails then save installer exit code and the return the saved code.

just clone this repo and run like this:
(1.2.3.4) is the ip in which the desired ELK server is listening
bash refac2_elk.sh "http://1.2.3.4:80" "1.2.3.4"
