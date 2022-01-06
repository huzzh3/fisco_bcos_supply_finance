#!/bin/bash

function usage()
{
    echo " Usage : "
    echo "   bash finance_run.sh deploy"
    echo "   bash finance_run.sh query     company_name "
    echo "   bash finance_run.sh register  company_name asset_receivable "
    echo "   bash finance_run.sh send      from_company_name to_company_name asset_receivable"
    echo "   bash finance_run.sh transfer  from_company_name to_company_name asset_receivable"
    echo "   bash finance_run.sh financing from_company_name asset_receivable"
    echo "   bash finance_run.sh settle    from_company_name to_company_name"
    echo " "
    echo " "
    echo "examples : "
    echo "   bash finance_run.sh deploy "
    echo "   bash finance_run.sh register carCompany 0 "
    echo "   bash finance_run.sh register tyreCompany 0 "
    echo "   bash finance_run.sh register wheelCompany 0 "
    echo "   bash finance_run.sh send carCompany tyreCompany 1000 "
    echo "   bash finance_run.sh transfer tyreCompany wheelCompany 500 "
    echo "   bash finance_run.sh financing tyreCompany 500 "
    echo "   bash finance_run.sh financing wheelCompany 500 "
    echo "   bash finance_run.sh query tyreCompany"
    echo "   bash finance_run.sh query wheelCompany"
    echo "   bash finance_run.sh settle carCompany tyreCompany"
    echo "   bash finance_run.sh settle carCompany wheelCompany"
    exit 0
}

    case $1 in
    deploy)
            [ $# -lt 1 ] && { usage; }
            ;;
    register)
            [ $# -lt 3 ] && { usage; }
            ;;
    send)
            [ $# -lt 4 ] && { usage; }
            ;;
    transfer)
            [ $# -lt 4 ] && { usage; }
            ;;
    financing)
            [ $# -lt 3 ] && { usage; }
            ;;
    query)
            [ $# -lt 2 ] && { usage; }
            ;;
    settle)
            [ $# -lt 3 ] && { usage; }
            ;;
    *)
        usage
            ;;
    esac

    java -Djdk.tls.namedGroups="secp256k1" -cp 'apps/*:conf/:lib/*' org.fisco.bcos.supplyChainFinance.client.SupplyChainFinanceClient $@

