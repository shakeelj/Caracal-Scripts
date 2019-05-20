    
PEM certificate to text
openssl x509 -text -in <filename>.crt > <filename>.crt.txt


PEM CSR to text (certificate signing request)
openssl req -text -noout -in <filename>.csr > <filename>.csr.txt
