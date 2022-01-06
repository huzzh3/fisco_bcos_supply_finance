// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 < 0.7.0;
pragma experimental ABIEncoderV2;

import "./KVTable.sol";

contract SupplyChainFinance {
    /* coreCompany 即核心企业 */
    string  public coreCompanyName;

    /* RegisterEvent 是注册事件，company 是公司名，assetReceivable 是应收账款
     * SendEvent 为签发应收账款
     * transferEvent 为转让应收账款
     * financingEvent 为向银行申请融资
     * settleEvent 为结算账款
     */
    event RegisterEvent(
        int256          ret, 
        string  indexed company, 
        uint256 indexed assetReceivable
    );
    event SendEvent(
        int256          ret,
        string  indexed fromCompany,
        string  indexed toCompany,
        uint256 indexed assetReceivableTo
    );
    event TransferEvent(
        int256          ret,
        string  indexed fromCompany,
        string  indexed toCompany,
        uint256 indexed assetReceivableTo
    );
    event FinancingEvent(
        int256          ret,
        string  indexed fromCompany,
        uint256 indexed assetReceivableTo
    );
    event SettleEvent(
        int256          ret,
        string  indexed fromCompany,
        string  indexed toCompany 
    );

    KVTable tf;

    constructor() public {
        // 创建应收账款表 asset_r
        tf = KVTable(0x1009);
        tf.createTable("asset_r", "company", "asset_receivable");
        // 初始化
        coreCompanyName = "carCompany";
    }

    /* register 为公司注册函数
     * 参数：
     *          company         ： 公司名
     *          assetReceivable ： 应收账款（初始化的时候应该设置为 0）
     * 返回值：
     *          0  : 注册成功
     *          -1 : 该公司已存在
     *          -2 : 插入数据时发生错误
     */
    function register(string memory company, uint256 assetReceivable) public returns (int256) {
        int256  retCode             = 0;
        bool    ret                 = true;
        uint256 tempAssetReceivable = 0;

        // 查询该公司名是否在表中
        (ret, tempAssetReceivable) = select(company);

        if (ret == false) {
            // 此公司不在表中，需要将此公司插入表中
            string    memory assetReceivableStr = uint2str(assetReceivable);
            KVField   memory kv1                = KVField("asset_receivable", assetReceivableStr);
            KVField[] memory KVFields           = new KVField[](1);
            KVFields[0]                         = kv1;
            Entry     memory entry              = Entry(KVFields);

            // 表项已经创建好了，现在将该表项插入表中
            int256 count = tf.set("asset_r", company, entry);

            // 判断插入是否成功
            if (count == 1) {
                retCode = 0;
            }
            else {
                retCode = -2;
            }
        }
        else {
            retCode = -1;
        }

        emit RegisterEvent(retCode, company, assetReceivable);

        return retCode;
    }

    /* send 函数能够让上游企业给下游企业签发应收账款 
     * 根据我对题目的理解，由于银行只认可核心企业的信用，
     * 故我认为，只有核心企业发放的应收账款才“有效”
     * 故只有核心企业能够发放应收账款
     *
     * 参数：
     *          fromCompany       : 签发的上游公司名(必须为核心公司)
     *          toCompany         : 目标下游公司名
     *          assetReceivableTo : 签发应收账款的金额
     * 返回值：
     *          0  : 签发成功
     *          -1 : 申请签发的公司不是核心公司
     *          -2 : 申请签发的公司不存在
     *          -3 : 目标公司不存在
     *          -4 : 签发的金额溢出
     *          -5 : 对表的更改发生了错误
     */
    function send(string memory fromCompany, string memory toCompany, uint256 assetReceivableTo) public returns (int256) {
        int256  retCode              = 0;
        bool    ret1                 = true;
        bool    ret2                 = true;
        uint256 tempAssetReceivable1 = 0;
        uint256 tempAssetReceivable2 = 0;

        // 查询签发公司是否在表中
        (ret1, tempAssetReceivable1) = select(fromCompany);
        // 查询目标公司是否在表中
        (ret2, tempAssetReceivable2) = select(toCompany);

        if (keccak256(bytes(fromCompany)) != keccak256(bytes(coreCompanyName))) {
            // 签发公司不是核心公司
            retCode = -1;
        }
        else if (ret1 == false) {
            // 签发公司不在表中
            retCode = -2;
        }
        else if (ret2 == false) {
                // 目标公司不在表中
                retCode = -3;
        }
        else if (tempAssetReceivable2 + assetReceivableTo < tempAssetReceivable2) {
                // 签发的金额发生了溢出
                retCode = -4;
        }
        else {
            // 此时对表进行修改
            string    memory companyNewAssetReceivable = uint2str(tempAssetReceivable2 + assetReceivableTo);
            KVField   memory kv1                       = KVField("asset_receivable", companyNewAssetReceivable);
            KVField[] memory KVFields                  = new KVField[](1);
            KVFields[0]                                = kv1;
            Entry     memory entry                     = Entry(KVFields);

            // 数据项设置完毕，将其同步到表中
            int256 count = tf.set("asset_r", toCompany, entry);

            // 判断同步是否成功
            if (count != 1) {
                retCode = -5;
            }
            else {
                retCode = 0;
            }
        }

        emit SendEvent(retCode, fromCompany, toCompany, assetReceivableTo);

        return retCode;
    }

    /* transfer 函数用于在下游公司中转让应收账款
     * 参数：
     *          fromCompany       ：转让的源公司
     *          toCompany         ：转让的目标公司
     *          assetReceivableTo ：转让的应收账款金额
     * 返回值：
     *          0  ：转让成功
     *          -1 ：转让的源公司是核心公司
     *          -2 ：转让的公司不存在
     *          -3 ：目标公司不存在
     *          -4 ：转让的金额不足
     *          -5 ：转让的金额溢出
     *          -6 ：对表的操作出现错误
     */
    function transfer(string memory fromCompany, string memory toCompany, uint256 assetReceivableTo) public returns (int256) {
        int256  retCode              = 0;
        bool    ret1                 = true;
        bool    ret2                 = true;
        uint256 tempAssetReceivable1 = 0;
        uint256 tempAssetReceivable2 = 0;

        // 查询签发公司是否在表中
        (ret1, tempAssetReceivable1) = select(fromCompany);
        // 查询目标公司是否在表中
        (ret2, tempAssetReceivable2) = select(toCompany);

        if (keccak256(bytes(fromCompany)) == keccak256(bytes(coreCompanyName))) {
            // 转让的源公司为核心公司
            retCode = -1;
        }
        else if (ret1 == false) {
            // 转让的源公司不存在
            retCode = -2;
        }
        else if (ret2 == false) {
            // 转让的目标公司不存在
            retCode = -3;
        }
        else if (tempAssetReceivable1 < assetReceivableTo) {
            // 转让的金额不足
            retCode = -4;
        }
        else if (tempAssetReceivable2 + assetReceivableTo < tempAssetReceivable2) {
            // 转让的金额溢出
            retCode = -5;
        }
        else {
            // 创建数据项
            string    memory tempAssetReceivableStr = uint2str(tempAssetReceivable1 - assetReceivableTo);
            KVField   memory kv                     = KVField("asset_receivable", tempAssetReceivableStr);
            KVField[] memory KVFields               = new KVField[](1);
            KVFields[0]                             = kv;
            Entry     memory entry                  = Entry(KVFields);

            // 更新转让的源公司的应收账款
            int256 count = tf.set("asset_r", fromCompany, entry);
            if (count != 1) {
                // 对表的修改失败
                retCode = -6;
            }
            else {
                // 创建另一个数据项
                tempAssetReceivableStr = uint2str(tempAssetReceivable2 + assetReceivableTo);
                kv                     = KVField("asset_receivable", tempAssetReceivableStr);
                KVFields               = new KVField[](1);
                KVFields[0]            = kv;
                entry                  = Entry(KVFields);

                // 更新转让的目标公司的应收账款
                count = tf.set("asset_r", toCompany, entry);
                if (count != 1) {
                    // 对表的修改失败
                    retCode = -6;
                }
                else {
                    retCode = 0;
                }
            }
        }

        emit TransferEvent(retCode, fromCompany, toCompany, assetReceivableTo);

        return retCode;
    }

    /* financing 函数能够让下游企业通过应收账款向银行申请融资
     * 参数:
     *          fromCompany       : 申请融资的公司
     *          assetReceivableTo : 申请融资的金额
     * 返回值:
     *          0  : 融资成功
     *          -1 : 该公司不存在
     *          -2 : 该公司的应收账款不足以申请该数目的贷款金额
     */
    function financing(string memory fromCompany, uint256 assetReceivableTo) public returns (int256) {
        int256  retCode             = 0;
        bool    ret                 = true;
        uint256 tempAssetReceivable = 0;

        // 对表进行查询
        (ret, tempAssetReceivable) = select(fromCompany);

        // 判断该公司是否存在
        if (ret == false) {
            // 该公司不存在
            retCode = -1;
        }
        else if (tempAssetReceivable < assetReceivableTo) {
            // 该公司的应收账款不足以申请该数目的贷款金额
            retCode = -2;
        }
        else {
            retCode = 0;
        }

        emit FinancingEvent(retCode, fromCompany, assetReceivableTo);

        return retCode;
    }

    /* settle 函数能够让核心公司结清下游公司的应收账款 
     * 参数:
     *          fromCompany : 结清账款的源公司(必须为核心公司)
     *            toCompany : 结清账款的目标公司
     * 返回值:
     *          0  : 结清成功
     *          -1 : 源公司不是核心公司
     *          -2 : 源公司不存在
     *          -3 : 目标公司不存在
     *          -4 : 对表的修改发生了错误
     */
    function settle(string memory fromCompany, string memory toCompany) public returns (int256) {
        int256  retCode              = 0;
        bool    ret1                 = true;
        bool    ret2                 = true;
        uint256 tempAssetReceivable1 = 0;
        uint256 tempAssetReceivable2 = 0;

        // 查询源公司是否在表中
        (ret1, tempAssetReceivable1) = select(fromCompany);
        // 查询目标公司是否在表中
        (ret2, tempAssetReceivable2) = select(toCompany);

        if (keccak256(bytes(fromCompany)) != keccak256(bytes(coreCompanyName))) {
            // 结清账款的源公司不是核心公司
            retCode = -1;
        }
        else if (ret1 == false) {
            // 结清账款的源公司不存在
            retCode = -2;
        }
        else if (ret2 == false) {
            // 结清账款的目标公司不存在
            retCode = -3;
        }
        else {
            // 创建数据项
            string    memory tempAssetReceivable2Str = uint2str(0);
            KVField   memory kv                      = KVField("asset_receivable", tempAssetReceivable2Str);
            KVField[] memory KVFields                = new KVField[](1);
            KVFields[0]                              = kv;
            Entry     memory entry                   = Entry(KVFields);

            // 更新目标公司的应收账款
            int256 count = tf.set("asset_r", toCompany, entry);

            if (count != 1) {
                // 对表的修改失败
                retCode = -4;
            }
            else {
                retCode = 0;
            }
        }

        emit SettleEvent(retCode, fromCompany, toCompany);

        return retCode;
    }
    
    /*-------------------------------- util 函数 --------------------------------*/

    /* select 函数能够对表进行查询
     * 参数：
     *          company : 公司名
     * 返回值：
     *          1 bool    返回值 : 0 表示账户存在，1 表示账户不存在
     *          2 uint256 返回值 : 应收账款，仅在第一个参数为 0 的时候有效
     */
    function select(string memory company) public view returns (bool, uint256) {
        Entry memory entry;
        bool         result;
        uint256      asset_receivable = 0;

        (result, entry) = tf.get("asset_r", company);

        if (entry.fields.length == 0) {
            return (false, 0);
        }
        else {
            asset_receivable = safeParseInt(entry.fields[0].value);
            return (result, asset_receivable);
        }
    }

    function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len - 1;
        while (_i != 0) {
            bstr[k--] = bytes1(uint8(48 + (_i % 10)));
            _i /= 10;
        }
        return string(bstr);
    }

    function safeParseInt(string memory _a) internal pure returns (uint256 _parsedInt) {
        return safeParseInt(_a, 0);
    }

    function safeParseInt(string memory _a, uint256 _b) internal pure returns (uint256 _parsedInt) {
        bytes memory bresult = bytes(_a);
        uint256 mint = 0;
        bool decimals = false;
        for (uint256 i = 0; i < bresult.length; i++) {
            if (
                (uint256(uint8(bresult[i])) >= 48) &&
                (uint256(uint8(bresult[i])) <= 57)
            ) {
                if (decimals) {
                    if (_b == 0) break;
                    else _b--;
                }
                mint *= 10;
                mint += uint256(uint8(bresult[i])) - 48;
            } else if (uint256(uint8(bresult[i])) == 46) {
                require(
                    !decimals,
                    "More than one decimal encountered in string!"
                );
                decimals = true;
            } else {
                revert("Non-numeral character encountered in string!");
            }
        }
        if (_b > 0) {
            mint *= 10**_b;
        }
        return mint;
    }
}