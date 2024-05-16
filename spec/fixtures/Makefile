all:
	@rm -f ca_crt.pem rip.mcollective.key rip.mcollective.pem
	cfssl genkey -initca ca_crt.json | cfssljson -bare ca_crt
	cfssl genkey -initca other_ca.json | cfssljson -bare other_ca
	cfssl genkey -initca devco.json | cfssljson -bare devco.net

	cfssl genkey other.mcollective.json | cfssljson -bare other.mcollective
	cfssl sign -ca other_ca.pem -ca-key other_ca-key.pem other.mcollective.csr other.mcollective.json | cfssljson -bare other.mcollective && openssl x509 -in other.mcollective.pem -noout -text

	cfssl genkey rip.mcollective.json | cfssljson -bare rip.mcollective
	cfssl sign -ca ca_crt.pem -ca-key ca_crt-key.pem rip.mcollective.csr rip.mcollective.json | cfssljson -bare rip.mcollective && openssl x509 -in rip.mcollective.pem -noout -text

	cfssl genkey test-cert.json | cfssljson -bare test-cert
	cfssl sign -ca devco.net.pem -ca-key devco.net-key.pem test-cert.csr test-cert.json | cfssljson -bare test-cert && openssl x509 -in test-cert.pem -noout -text
