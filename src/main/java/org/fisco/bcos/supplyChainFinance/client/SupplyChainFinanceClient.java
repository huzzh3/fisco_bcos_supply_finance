package org.fisco.bcos.supplyChainFinance.client;

import org.fisco.bcos.sdk.BcosSDK;
import org.fisco.bcos.sdk.client.Client;
import org.fisco.bcos.sdk.codec.datatypes.generated.tuples.generated.Tuple1;
import org.fisco.bcos.sdk.codec.datatypes.generated.tuples.generated.Tuple2;
import org.fisco.bcos.sdk.crypto.keypair.CryptoKeyPair;
import org.fisco.bcos.sdk.model.TransactionReceipt;
import org.fisco.bcos.supplyChainFinance.contract.SupplyChainFinance;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationContext;
import org.springframework.context.support.ClassPathXmlApplicationContext;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;

import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.math.BigInteger;
import java.util.Objects;
import java.util.Properties;

public class SupplyChainFinanceClient {

    static Logger logger = LoggerFactory.getLogger(org.fisco.bcos.supplyChainFinance.client.SupplyChainFinanceClient.class);

    private BcosSDK bcosSDK;
    private Client client;
    private CryptoKeyPair cryptoKeyPair;

    public void initialize() throws Exception {
        @SuppressWarnings("resource")
        ApplicationContext context =
                new ClassPathXmlApplicationContext("classpath:applicationContext.xml");
        bcosSDK = context.getBean(BcosSDK.class);
        client = bcosSDK.getClient();
        cryptoKeyPair = client.getCryptoSuite().getCryptoKeyPair();
        client.getCryptoSuite().setCryptoKeyPair(cryptoKeyPair);
        logger.debug("create client for group, account address is " + cryptoKeyPair.getAddress());
    }

    public void deployCompanyAndRecordAddr() {
        try {
            SupplyChainFinance company = SupplyChainFinance.deploy(client, cryptoKeyPair);
            System.out.println(
                    " deploy Asset success, contract address is " + company.getContractAddress());

            recordCompanyAddr(company.getContractAddress());
        } catch (Exception e) {
            System.out.println(" deploy Asset contract failed, error message is  " + e.getMessage());
        }
    }

    public void recordCompanyAddr(String address) throws FileNotFoundException, IOException {
        Properties prop = new Properties();
        prop.setProperty("address", address);
        final Resource contractResource = new ClassPathResource("contract.properties");
        FileOutputStream fileOutputStream = new FileOutputStream(contractResource.getFile());
        prop.store(fileOutputStream, "contract address");
    }

    public String loadCompanyAddr() throws Exception {
        // load Asset contact address from contract.properties
        Properties prop = new Properties();
        final Resource contractResource = new ClassPathResource("contract.properties");
        prop.load(contractResource.getInputStream());

        String contractAddress = prop.getProperty("address");
        if (contractAddress == null || contractAddress.trim().equals("")) {
            throw new Exception(" load Company contract address failed, please deploy it first. ");
        }
        logger.info(" load Company address from contract.properties, address is {}", contractAddress);
        return contractAddress;
    }

    public void queryAssetAmount(String companyAccount) {
        try {
            String contractAddress   = loadCompanyAddr();
            SupplyChainFinance company = SupplyChainFinance.load(contractAddress, client, cryptoKeyPair);
            Tuple2<Boolean, BigInteger> result = company.select(companyAccount);
            if (result.getValue1()) {
                System.out.printf(" company %s, asset receivable: %s \n", companyAccount, result.getValue2());
            } else {
                System.out.printf(" %s company is not exist \n", companyAccount);
            }
        } catch (Exception e) {
            logger.error(" queryAssetAmount exception, error message is {}", e.getMessage());

            System.out.printf(" query asset account failed, error message is %s\n", e.getMessage());
        }
    }

    public void registerCompanyAccount(String companyAccount, BigInteger amount) {
        try {
            String contractAddress = loadCompanyAddr();

            SupplyChainFinance company = SupplyChainFinance.load(contractAddress, client, cryptoKeyPair);
            TransactionReceipt receipt = company.register(companyAccount, amount);
            Tuple1<BigInteger> registerOutput = company.getRegisterOutput(receipt);
            if (receipt.getStatus() == 0) {
                if (Objects.equals(registerOutput.getValue1(), BigInteger.valueOf(0))) {
                    System.out.printf(" register company account success => company: %s, asset receivable: %s \n", companyAccount, amount);
                }
                else if (Objects.equals(registerOutput.getValue1(), BigInteger.valueOf(-1))) {
                    System.out.printf(" company %s is exist, error \n", companyAccount);
                }
                else if (Objects.equals(registerOutput.getValue1(), BigInteger.valueOf(-2))){
                    System.out.printf(" there're some error while operating the table \n");
                }
                else {
                    System.out.printf(" unknown error \n");
                }
            } else {
                System.out.println(" receipt status is error, maybe transaction not exec, status is: " + receipt.getStatus());
            }
        } catch (Exception e) {
            logger.error(" registerCompanyAccount exception, error message is {}", e.getMessage());
            System.out.printf(" register company account failed, error message is %s\n", e.getMessage());
        }
    }

    public void sendCompanyAccount(String fromCompanyAccount, String toCompanyAccount, BigInteger amount) {
        try {
            String contractAddress        = loadCompanyAddr();
            SupplyChainFinance supply     = SupplyChainFinance.load(contractAddress, client, cryptoKeyPair);
            TransactionReceipt receipt    = supply.send(fromCompanyAccount, toCompanyAccount, amount);
            Tuple1<BigInteger> sendOutput = supply.getSendOutput(receipt);

            if (receipt.getStatus() == 0) {
                if (Objects.equals(sendOutput.getValue1(), BigInteger.valueOf(0))) {
                    System.out.printf(" send success => from_company: %s, to_company: %s, amout: %s \n",
                                        fromCompanyAccount, toCompanyAccount, amount);
                }
                else if (Objects.equals(sendOutput.getValue1(), BigInteger.valueOf(-1))) {
                    System.out.printf(" send failed, the company send the asset is not the core company \n");
                }
                else if (Objects.equals(sendOutput.getValue1(), BigInteger.valueOf(-2))) {
                    System.out.printf(" send failed, the company send the asset is not exist \n");
                }
                else if (Objects.equals(sendOutput.getValue1(), BigInteger.valueOf(-3))) {
                    System.out.printf(" send failed, the company receive the asset is not exist \n");
                }
                else if (Objects.equals(sendOutput.getValue1(), BigInteger.valueOf(-4))) {
                    System.out.printf(" send failed, the amount is overflow \n");
                }
                else if (Objects.equals(sendOutput.getValue1(), BigInteger.valueOf(-5))) {
                    System.out.printf(" send failed, there're some error while operating the table \n");
                }
                else {
                    System.out.printf(" unknown error \n");
                }
            }
            else {
                System.out.println(" receipt status is error, maybe transaction not exec, status is: " + receipt.getStatus());
            }

        } catch (Exception e) {
            logger.error(" send exception, error message is {}", e.getMessage());
            System.out.printf(" send failed, error message is %s\n", e.getMessage());
        }
    }

    public void transferAsset(String fromCompanyAccount, String toCompanyAccount, BigInteger amount) {
        try {
            String contractAddress   = loadCompanyAddr();
            SupplyChainFinance company = SupplyChainFinance.load(contractAddress, client, cryptoKeyPair);
            TransactionReceipt receipt = company.transfer(fromCompanyAccount, toCompanyAccount, amount);
            Tuple1<BigInteger> transferOutput = company.getTransferOutput(receipt);
            if (receipt.getStatus() == 0) {
                if (Objects.equals(transferOutput.getValue1(), BigInteger.valueOf(0))) {
                    System.out.printf(
                            " transfer success => from_company: %s, to_company: %s, amount: %s \n",
                            fromCompanyAccount, toCompanyAccount, amount);
                }
                else if (Objects.equals(transferOutput.getValue1(), BigInteger.valueOf(-1))) {
                    System.out.printf(" transfer error, the from_company is core company \n");
                }
                else if (Objects.equals(transferOutput.getValue1(), BigInteger.valueOf(-2))) {
                    System.out.printf(" transfer error, the from_company is not exist \n");
                }
                else if (Objects.equals(transferOutput.getValue1(), BigInteger.valueOf(-3))) {
                    System.out.printf(" transfer error, the to_company is not exist \n");
                }
                else if (Objects.equals(transferOutput.getValue1(), BigInteger.valueOf(-4))) {
                    System.out.printf(" transfer error, the amount is not enough \n");
                }
                else if (Objects.equals(transferOutput.getValue1(), BigInteger.valueOf(-5))) {
                    System.out.printf(" transfer error, the amount is overflow \n");
                }
                else if (Objects.equals(transferOutput.getValue1(), BigInteger.valueOf(-6))) {
                    System.out.printf(" send failed, there're some error while operating the table \n");
                }
                else {
                    System.out.printf(" unknown error \n");
                }
            } else {
                System.out.println(" receipt status is error, maybe transaction not exec. status is: " + receipt.getStatus());
            }
        } catch (Exception e) {
            logger.error(" transferAsset exception, error message is {}", e.getMessage());
            System.out.printf(" transfer asset account failed, error message is %s\n", e.getMessage());
        }
    }

    public void financingAsset(String fromCompany, BigInteger amount) {
        try {
            String contractAddress     = loadCompanyAddr();
            SupplyChainFinance company = SupplyChainFinance.load(contractAddress, client, cryptoKeyPair);
            TransactionReceipt receipt = company.financing(fromCompany, amount);
            Tuple1<BigInteger> transferOutput = company.getTransferOutput(receipt);
            if (receipt.getStatus() == 0) {
                if (Objects.equals(transferOutput.getValue1(), BigInteger.valueOf(0))) {
                    System.out.printf(" financing success => company %s get %s from bank \n", fromCompany, amount);
                }
                else if (Objects.equals(transferOutput.getValue1(), BigInteger.valueOf(-1))) {
                    System.out.printf(" financing error, the company is not exist \n");
                }
                else if (Objects.equals(transferOutput.getValue1(), BigInteger.valueOf(-2))) {
                    System.out.printf(" financing error, the amount is bigger than asset receivable \n");
                }
                else {
                    System.out.printf(" unknown error \n");
                }
            } else {
                System.out.println(" receipt status is error, maybe transaction not exec. status is: " + receipt.getStatus());
            }
        } catch (Exception e) {
            logger.error(" financing exception, error message is {}", e.getMessage());
            System.out.printf(" financing failed, error message is %s\n", e.getMessage());
        }
    }

    public void settleAsset(String fromCompany, String toCompany) {
        try {
            String contractAddress     = loadCompanyAddr();
            SupplyChainFinance company = SupplyChainFinance.load(contractAddress, client, cryptoKeyPair);
            TransactionReceipt receipt = company.settle(fromCompany, toCompany);
            Tuple1<BigInteger> transferOutput = company.getTransferOutput(receipt);
            if (receipt.getStatus() == 0) {
                if (Objects.equals(transferOutput.getValue1(), BigInteger.valueOf(0))) {
                    System.out.printf(" settle success => company %s haven't asset receivable now \n", toCompany);
                }
                else if (Objects.equals(transferOutput.getValue1(), BigInteger.valueOf(-1))) {
                    System.out.printf(" settle failed, the from_company isn't the core company \n");
                }
                else if (Objects.equals(transferOutput.getValue1(), BigInteger.valueOf(-2))) {
                    System.out.printf(" settle failed, the from_company isn't exist \n");
                }
                else if (Objects.equals(transferOutput.getValue1(), BigInteger.valueOf(-3))) {
                    System.out.printf(" settle failed, the to_company isn't exist \n");
                }
                else if (Objects.equals(transferOutput.getValue1(), BigInteger.valueOf(-4))) {
                    System.out.printf(" settle failed, there're some error while operating the table \n");
                }
                else {
                    System.out.printf(" unknown error \n");
                }
            } else {
                System.out.println(" receipt status is error, maybe transaction not exec. status is: " + receipt.getStatus());
            }
        } catch (Exception e) {
            logger.error(" settle exception, error message is {}", e.getMessage());
            System.out.printf(" settle failed, error message is %s\n", e.getMessage());
        }
    }

    public static void Usage() {
        System.out.println(" Usage:");
        System.out.println(
                "\t java -cp 'conf/:lib/*:apps/*' org.fisco.bcos.asset.client.AssetClient deploy");
        System.out.println(
                "\t java -cp 'conf/:lib/*:apps/*' org.fisco.bcos.asset.client.AssetClient query account");
        System.out.println(
                "\t java -cp 'conf/:lib/*:apps/*' org.fisco.bcos.asset.client.AssetClient register account value");
        System.out.println(
                "\t java -cp 'conf/:lib/*:apps/*' org.fisco.bcos.asset.client.AssetClient transfer from_account to_account amount");
        System.exit(0);
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 1) {
            Usage();
        }

        org.fisco.bcos.supplyChainFinance.client.SupplyChainFinanceClient client = new org.fisco.bcos.supplyChainFinance.client.SupplyChainFinanceClient();
        client.initialize();

        switch (args[0]) {
            case "deploy":
                client.deployCompanyAndRecordAddr();
                break;
            case "query":
                if (args.length < 2) {
                    Usage();
                }
                client.queryAssetAmount(args[1]);
                break;
            case "send":
                if (args.length < 4) {
                    Usage();
                }
                client.sendCompanyAccount(args[1], args[2], new BigInteger(args[3]));
                break;
            case "register":
                if (args.length < 3) {
                    Usage();
                }
                client.registerCompanyAccount(args[1], new BigInteger(args[2]));
                break;
            case "transfer":
                if (args.length < 4) {
                    Usage();
                }
                client.transferAsset(args[1], args[2], new BigInteger(args[3]));
                break;
            case "financing":
                if (args.length < 3) {
                    Usage();
                }
                client.financingAsset(args[1], new BigInteger(args[2]));
                break;
            case "settle":
                if (args.length < 3) {
                    Usage();
                }
                client.settleAsset(args[1], args[2]);
                break;
            default:
            {
                Usage();
            }
        }
        System.exit(0);
    }
}
