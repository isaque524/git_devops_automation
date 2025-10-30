#!/bin/bash

KEY_NAME="devops-keypair-01"
SG_NAME="devops-sg-ie"

VPC_ID=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)

SUBNET_ID=$(aws ec2 describe-subnets --filters Name=default-for-az,Values=true --query 'Subnets[0].SubnetId' --output text)

AMI_ID=$(aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" --output text)

# Create Key Pair
aws ec2 describe-key-pairs --key-names $KEY_NAME >/dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "Creating Key Pair: $KEY_NAME"
    aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "$KEY_NAME.pem"
    chmod 400 "$KEY_NAME.pem"
else
    echo "Key Pair $KEY_NAME já existe na AWS. Pulando criação."
    if [ ! -f "$KEY_NAME.pem" ]; then
        echo "Arquivo $KEY_NAME.pem não encontrado localmente. Por favor, obtenha a chave privada correspondente."
        exit 1
    fi
fi  

# Verificar se SG já existe
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SG_NAME" "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
    echo " Criando Security Group: $SG_NAME"
    SG_ID=$(aws ec2 create-security-group --group-name "$SG_NAME" --description "Acesso via SSH" --vpc-id "$VPC_ID" --query 'GroupId' --output text)

    echo " SG criado: $SG_ID"
    aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0
else
    echo " Security Group já existe: $SG_ID"
fi

# Lista de nomes
VM_NAMES=(vm-01 vm-02 vm-03)

for VM_NAME in "${VM_NAMES[@]}"; do
    echo "Criando a VM: $VM_NAME"
    
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --count 1 \
        --instance-type t3.micro \
        --key-name "$KEY_NAME" \
        --security-group-ids "$SG_ID" \
        --subnet-id "$SUBNET_ID" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$VM_NAME}]" \
        --query 'Instances[0].InstanceId' \
        --output text)
    echo "Instância $VM_NAME criada com ID: $INSTANCE_ID"

    # Esperar até que a instância esteja em execução
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
    echo "Instância $VM_NAME está em execução."
done