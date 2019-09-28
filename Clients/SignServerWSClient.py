from zeep import Client
import argparse


parser = argparse.ArgumentParser()
parser.add_argument("--pdf" , help="Le fichier pdf a signer, chemin absolue")
parser.add_argument("--wsdl" , help="url vers SignServer")
parser.add_argument("--password" , help="mot de passe de pdf s'il est protégé")
args = parser.parse_args()

if [args.password]:
	password = args.password
else:
	password = ""

worker="PDFSigner"

with open(args.pdf, "rb") as file:
    data = file.read()


client = Client(wsdl=args.wsdl)

metadata_type = client.get_type('ns0:metadata')
metadata = metadata_type(password,'pdfPassword')

result = client.service.processData(worker,metadata,data)

print("Archive ID: ", result.archiveId)
print("Metadata :", result.metadata)
print("Request ID ",result.requestId)
print("Signer's Certificates", result.signerCertificate.hex())

file = open("out.pdf", "wb")
file.write(result.data)
file.close()
