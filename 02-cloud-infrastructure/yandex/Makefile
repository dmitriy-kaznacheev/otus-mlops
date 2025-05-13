init:
	terraform init -upgrade

plan:
	terraform plan

apply: 
	terraform apply -auto-approve

destroy:
	terraform destroy -auto-approve
clean: destroy
	rm -rf .terraform
	rm -f *.tfplan *.tfstate *.tfstate.backup *.tfstate.backup.* .terraform.lock.hcl
