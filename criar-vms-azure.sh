#!/bin/bash

RESOURCE_GROUP="terraform-demo-rg"
LOCATION="eastus2"
PASSWORD="SenhaForte123"

criar_vm() {
    local NOME_VM=$1
    echo "Criando VM:  $NOME_VM"

    az vm create \
        --resource-group $RESOURCE_GROUP \
        --name $NOME_VM \
        --image Ubuntu2204 \
        --admin-username azureuser \
        --admin-password $PASSWORD \
        --authentication-type password \
        --location $LOCATION \
        --size Standard_B1s \
        --no-wait
}

# Lista de VMs para criar

VMS=(vm01 vm02)

for nome in "${VMS[@]}"; do
    criar_vm $nome
done

echo "Criação em lote iniciada para as VMs: ${VMS[*]}"
