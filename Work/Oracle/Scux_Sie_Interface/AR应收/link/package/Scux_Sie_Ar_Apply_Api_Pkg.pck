CREATE OR REPLACE PACKAGE Scux_Sie_Ar_Apply_Api_Pkg IS

  /*=============================================================
  Copyright (C)  SIE Consulting Co., Ltd    
  All rights reserved 
  ===============================================================
  Program Name:   Scux_Sie_Gl_Journals_Api_Pkg
  Author      :   SIE ����
  Created:    :   2018-09-21
  Purpose     :   
  Description : ��׼�����������Ʊ����API
  
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0     2018-09-21    SIE ����        Creation
  V1.1     2018-12-16    SIE ����        ��׼���޶�
  V1. 2       2019-03-12    SIE�ſ�ӯ      Do_Import�������Pv_Created_by������Scux_Sie_Interface_Pkg.Get_Created_By(Pv_Created_By);
  
  ===============================================================*/

  /*===============================================================
  Program Name:   Do_Import
  Author      :   SIE ����
  Created:   :    2018-09-21
  Purpose     :  ���������Ʊ����API
  Parameters  :
              Pt_Iface_Tbl         IN Scux_Sie_Gl_Journal_Tbl --�ռ�������Ϣ
              Pv_Scux_Source_Code  IN VARCHAR2 --������Դ
              Pv_Synchro_Flag      IN VARCHAR2 --ͬ�������첽���÷�ʽ
              Pv_Init_Flag         IN VARCHAR2 --��Χϵͳ������Ҫ��ʼ������
              Pv_Language          IN VARCHAR2 --����
  Return  :
              Xn_Scux_Session_Id   OUT NUMBER  --����ID
              Xv_Ret_Status        OUT VARCHAR2--״̬
              Xv_Ret_Message       OUT VARCHAR2--������Ϣ
  Description: ���������Ʊ����API
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-25    SIE ����         Creation 
   V1. 2       2019-03-12    SIE�ſ�ӯ      Do_Import�������Pv_Created_by������Scux_Sie_Interface_Pkg.Get_Created_By(Pv_Created_By);   
  ===============================================================*/
  PROCEDURE Do_Import(Pt_Iface_Tbl        IN Scux_Sie_Ar_Apply_Tbl
                     ,Pv_Scux_Source_Code IN VARCHAR2
                     ,Pv_Synchro_Flag     IN VARCHAR2 DEFAULT 'Y' -- �Ƿ�ͬ������
                     ,Pv_Init_Flag        IN VARCHAR2 DEFAULT 'Y' --�Ƿ��ʼ������
                     ,Pv_Language         IN VARCHAR2 DEFAULT 'ZHS'
                     ,Xn_Scux_Session_Id  OUT NUMBER
                     ,Xv_Ret_Status       OUT VARCHAR2
                     ,Xv_Ret_Message      OUT VARCHAR2
                     ,Pv_Created_By       IN VARCHAR2 DEFAULT NULL --V1.2 MOD
                      );

END Scux_Sie_Ar_Apply_Api_Pkg;
/
CREATE OR REPLACE PACKAGE BODY Scux_Sie_Ar_Apply_Api_Pkg IS

  Gv_Package_Name CONSTANT VARCHAR2(30) := 'Scux_Sie_Ar_apply_Api_Pkg';
  Gv_Pending      CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Pending; -- 'PENDING'; --����
  Gv_Running      CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Running; -- 'RUNNING'; --������
  Gv_Submit       CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Submit; -- 'SUBMIT'; --���ύ(�����첽���ò��������м�״̬
  Gv_Completed    CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Completed; -- 'COMPLETED'; --�����
  Gv_Error        CONSTANT VARCHAR2(20) := Scux_Sie_Interface_Pkg.Gv_Error; -- 'ERROR'; --����

  Gv_Date_Type CONSTANT VARCHAR2(20) := 'SOA';

  Gv_Application_Code CONSTANT VARCHAR2(30) := Scux_Fnd_Log.Gv_Application_Code;
  --v1.2    ADD   START--
  Gn_User_Id NUMBER := Fnd_Global.User_Id; --��¼ERP�˺�ID
  --V1.2    ADD    END--
  /*===============================================================
  Program Name:   Validate_Data
  Author      :   SIE ����
  Created:    :   2018-07-01
  Purpose     :   ��֤�������ֶβ���Ϊ��
  Parameters  :
              Pt_Iface_Tbl         IN Scux_Sie_Gl_Journal_Tbl --�ռ�������Ϣ
              Pv_Scux_Source_Code  IN VARCHAR2 --������Դ
  Return  :
              Xv_Ret_Status        OUT VARCHAR2--״̬
              Xv_Ret_Message       OUT VARCHAR2--������Ϣ
  Description: ��֤�������ֶβ���Ϊ��
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-25    SIE ����         Creation    
  V1.1      2018-12-16    SIE ����         ȥ����Ҫ����֤
  ===============================================================*/
  PROCEDURE Validate_Data(Pt_Iface_Tbl        IN Scux_Sie_Ar_Apply_Tbl
                         ,Pv_Scux_Source_Code IN VARCHAR
                         ,Xv_Ret_Status       OUT VARCHAR2
                         ,Xv_Ret_Message      OUT VARCHAR2) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Validate_Date';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  
    Ln_Count               NUMBER;
    Ln_Pay_From_Customer   NUMBER;
    Ln_Bill_To_Customer_Id NUMBER;
  
    Lt_Iface_Rec Scux_Sie_Ar_Apply_Iface%ROWTYPE;
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    IF Pv_Scux_Source_Code IS NULL THEN
      Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
      Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => Gv_Application_Code
                                                     ,Pv_Message_Name     => 'SCUX_SIE_PUB_001' --����Ϊ��
                                                     ,Pv_Token1           => '1'
                                                     ,Pv_Value1           => 'Scux_Source_Code');
      Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                    ,Pv_Status  => Xv_Ret_Status
                                    ,Pv_Message => Xv_Ret_Message);
    
    END IF;
  
    FOR i IN Pt_Iface_Tbl.First .. Pt_Iface_Tbl.Last LOOP
      --��Դnum����Ϊ��
      IF Pt_Iface_Tbl(i).Scux_Source_Num IS NULL THEN
        Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
        Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => Gv_Application_Code
                                                       ,Pv_Message_Name     => 'SCUX_SIE_PUB_001' --����Ϊ��
                                                       ,Pv_Token1           => '1'
                                                       ,Pv_Value1           => 'User_Je_Source_Name');
        Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                      ,Pv_Status  => Xv_Ret_Status
                                      ,Pv_Message => Xv_Ret_Message);
      END IF;
    
    END LOOP;
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Fnd_Exception.Handle_Exception(Pv_Api         => Lv_Api
                                         ,Xv_Ret_Status  => Xv_Ret_Status
                                         ,Xv_Ret_Message => Xv_Ret_Message);
  END Validate_Data;

  /*===============================================================
  Program Name:   Do_Insert_Process
  Author      :   SIE ����
  Created:    :   2018-07-01
  Purpose     :   ����д��ӿڱ�
  Parameters  :
              Pt_Iface_Tbl         IN Scux_Sie_Gl_Journal_Tbl --�ռ�������Ϣ
              Pn_Scux_Session_Id   IN NUMBER   --��������ID
              Pv_Scux_Source_Code  IN VARCHAR2 --������Դ
  Return  :
              Xn_Count             OUT NUMBER  --д��ӿڼ�¼��
              Xv_Ret_Status        OUT VARCHAR2--״̬
              Xv_Ret_Message       OUT VARCHAR2--������Ϣ
  Description: ���������Ʊ����API
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-25    SIE ����         Creation    
    V1.2     2019-03-12    SIE�ſ�ӯ       �޸�CREATED_BY��LAST_UPDATE_BY�Ĵ���
  ===============================================================*/
  PROCEDURE Do_Insert_Process(Pt_Iface_Tbl        IN Scux_Sie_Ar_Apply_Tbl
                             ,Pn_Scux_Session_Id  IN NUMBER
                             ,Pv_Scux_Source_Code IN VARCHAR2
                             ,Xn_Count            OUT NUMBER
                             ,Xv_Ret_Status       OUT VARCHAR2
                             ,Xv_Ret_Message      OUT VARCHAR2) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Do_Insert_Process';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  
    Lt_Iface_Rec                Scux_Sie_Ar_Apply_Iface%ROWTYPE;
    Ln_Count                    NUMBER := 0;
    Ln_Currency_Conversion_Rate NUMBER := 1;
  
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    FOR i IN Pt_Iface_Tbl.First .. Pt_Iface_Tbl.Last LOOP
      Lt_Iface_Rec := NULL;
    
      -----------------------------------------------  
      SELECT Scux_Sie_Ar_Apply_Iface_s.Nextval
        INTO Lt_Iface_Rec.Scux_Interface_Header_Id
        FROM Dual;
      Lt_Iface_Rec.Scux_Session_Id := Pn_Scux_Session_Id;
    
      Lt_Iface_Rec.Scux_Source_Code    := Scux_Sie_Interface_Pkg.Data_Format(Pv_Scux_Source_Code);
      Lt_Iface_Rec.Scux_Source_Num     := Scux_Sie_Interface_Pkg.Data_Format(Pt_Iface_Tbl(i)
                                                                             .Scux_Source_Num);
      Lt_Iface_Rec.Scux_Source_Id      := Scux_Sie_Interface_Pkg.Data_Format(Pt_Iface_Tbl(i)
                                                                             .Scux_Source_Id);
      Lt_Iface_Rec.Scux_Process_Status := Gv_Pending;
    
      -----------------------------------------------  
    
      Lt_Iface_Rec.Org_Id          := Scux_Sie_Interface_Pkg.Data_Format(Pt_Iface_Tbl(i) .
                                                                          Org_Id);
      Lt_Iface_Rec.Scux_Org_Name   := Scux_Sie_Interface_Pkg.Data_Format(Pt_Iface_Tbl(i) .
                                                                          Scux_Org_Name);
      Lt_Iface_Rec.Receipt_Number  := Scux_Sie_Interface_Pkg.Data_Format(Pt_Iface_Tbl(i) .
                                                                          Receipt_Number);
      Lt_Iface_Rec.Receipt_Id      := Scux_Sie_Interface_Pkg.Data_Format(Pt_Iface_Tbl(i)
                                                                         .Cash_Receipt_Id);
      Lt_Iface_Rec.Trx_Number      := Scux_Sie_Interface_Pkg.Data_Format(Pt_Iface_Tbl(i) .
                                                                          Trx_Number);
      Lt_Iface_Rec.Customer_Trx_Id := Scux_Sie_Interface_Pkg.Data_Format(Pt_Iface_Tbl(i) .
                                                                          Customer_Trx_Id);
      Lt_Iface_Rec.Applied_Amount  := Scux_Sie_Interface_Pkg.Data_Format(Pt_Iface_Tbl(i) .
                                                                          Applied_Amount);
    
      --�����ֶ�ת��
      Scux_Sie_Interface_Pkg.Date_Conversion(Pv_Date        => Scux_Sie_Interface_Pkg.Data_Format(Pt_Iface_Tbl(i)
                                                                                                  .Applied_Date)
                                            ,Pv_Date_Type   => Gv_Date_Type
                                            ,Xd_Date        => Lt_Iface_Rec.Applied_Date
                                            ,Xv_Ret_Status  => Xv_Ret_Status
                                            ,Xv_Ret_Message => Xv_Ret_Message);
    
      IF Xv_Ret_Status <> Fnd_Api.g_Ret_Sts_Success THEN
        Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                      ,Pv_Status  => Fnd_Api.g_Ret_Sts_Unexp_Error
                                      ,Pv_Message => 'APPLIED_DATE' ||
                                                     Xv_Ret_Message);
      END IF;
    
      --�����ֶ�ת��
      Scux_Sie_Interface_Pkg.Date_Conversion(Pv_Date        => Scux_Sie_Interface_Pkg.Data_Format(Pt_Iface_Tbl(i)
                                                                                                  .Applied_Gl_Date)
                                            ,Pv_Date_Type   => Gv_Date_Type
                                            ,Xd_Date        => Lt_Iface_Rec.Applied_Gl_Date
                                            ,Xv_Ret_Status  => Xv_Ret_Status
                                            ,Xv_Ret_Message => Xv_Ret_Message);
    
      IF Xv_Ret_Status <> Fnd_Api.g_Ret_Sts_Success THEN
        Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                      ,Pv_Status  => Fnd_Api.g_Ret_Sts_Unexp_Error
                                      ,Pv_Message => 'APPLIED_GL_DATE' ||
                                                     Xv_Ret_Message);
      END IF;
      --end -----------------------------------------
      IF Pt_Iface_Tbl(i).Currency_Conversion_Rate IS NULL THEN
        Ln_Currency_Conversion_Rate := 1;
      ELSE
        Ln_Currency_Conversion_Rate := Pt_Iface_Tbl(i)
                                       .Currency_Conversion_Rate;
      END IF;
      Lt_Iface_Rec.Currency_Conversion_Rate := Scux_Sie_Interface_Pkg.Data_Format(Ln_Currency_Conversion_Rate);
      --V1.2    MOD   START---
      --  Lt_Iface_Rec.Created_By       := Fnd_Global.User_Id;
      Lt_Iface_Rec.Created_By    := Gn_User_Id;
      Lt_Iface_Rec.Creation_Date := SYSDATE;
      --Lt_Iface_Rec.Last_Updated_By  := Fnd_Global.User_Id;
      Lt_Iface_Rec.Last_Updated_By := Gn_User_Id;
      --V1.2    MOD   END ---
      Lt_Iface_Rec.Last_Update_Date := SYSDATE;
    
      INSERT INTO Scux_Sie_Ar_Apply_Iface
      VALUES Lt_Iface_Rec;
      Ln_Count := Ln_Count + 1;
    END LOOP;
  
    COMMIT;
  
    Xn_Count      := Ln_Count;
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Fnd_Exception.Handle_Exception(Pv_Api         => Lv_Api
                                         ,Xv_Ret_Status  => Xv_Ret_Status
                                         ,Xv_Ret_Message => Xv_Ret_Message);
  END Do_Insert_Process;

  /*===============================================================
  Program Name:   Do_Submit_Process
  Author      :   SIE ����
  Created:    :   2018-07-01
  Purpose     :   ͬ�����첽�����ռ���ƾ֤����
  Parameters  :
              Pn_Scux_Session_Id   IN NUMBER   --����ID
              Pv_Scux_Source_Code  IN VARCHAR2 --������Դ
              Pv_Synchro_Flag      IN VARCHAR2 --ͬ�������첽���÷�ʽ
  Return  :
              Xv_Ret_Status        OUT VARCHAR2--״̬
              Xv_Ret_Message       OUT VARCHAR2--������Ϣ
  Description: ͬ�����첽�����ռ���ƾ֤���� API
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-25   SIE ����        Creation  
  V1.1      2018-12-16   SIE ����         ����Ƿ��ʼ������  
  ===============================================================*/
  PROCEDURE Do_Submit_Process(Pn_Scux_Session_Id  IN NUMBER
                             ,Pv_Scux_Source_Code IN VARCHAR
                             ,Pv_Synchro_Flag     IN VARCHAR2
                             ,Pv_Init_Flag        IN VARCHAR2 DEFAULT 'Y' --�Ƿ��ʼ������
                             ,Xv_Ret_Status       OUT VARCHAR2
                             ,Xv_Ret_Message      OUT VARCHAR2) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Do_Submit_Process';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  
    Ln_Count      NUMBER;
    Ln_Request_Id NUMBER;
  
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
    IF Pv_Synchro_Flag = 'Y' THEN
      Scux_Fnd_Log.Step(Lv_Api
                       ,'2.ͬ�����ã�-------------');
      Scux_Sie_Ar_Apply_Imp_Pkg.Do_Import(Pn_Scux_Session_Id  => Pn_Scux_Session_Id
                                         ,Pv_Scux_Source_Code => Pv_Scux_Source_Code
                                         ,Pv_Init_Flag        => Pv_Init_Flag --V1.1 MOD 'Y'
                                         ,Xv_Ret_Status       => Xv_Ret_Status
                                         ,Xv_Ret_Message      => Xv_Ret_Message);
      Scux_Fnd_Exception.Raise_Exception(Pv_Ret_Status  => Xv_Ret_Status
                                        ,Pv_Ret_Message => Xv_Ret_Message);
    ELSE
    
      Scux_Fnd_Log.Step(Lv_Api
                       ,'3.�첽���ã�-------------');
      Ln_Request_Id := Fnd_Request.Submit_Request(Gv_Application_Code
                                                 ,'SCUX_SIE_AR_APPLY_IMP_PKG'
                                                 ,'SCUX_AR�տ������Ʊ����'
                                                 ,To_Char(SYSDATE
                                                         ,'YYYY/MM/DD HH24:MI:SS')
                                                 ,FALSE
                                                 ,Pn_Scux_Session_Id
                                                 ,Pv_Scux_Source_Code
                                                 ,Pv_Init_Flag --V1.1--'N'
                                                 ,'N'
                                                 ,Chr(0));
    
      --  Log('lv_Request_Id=' || lv_Request_Id);
      IF Nvl(Ln_Request_Id
            ,0) = 0 THEN
      
        Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => 'AR'
                                                       ,Pv_Message_Name     => 'AR_API_SYSP_CONC_SUBMIT_FAIL' --δ���ύ��������                        
                                                        );
      
        Xv_Ret_Message := Lv_Api || Xv_Ret_Message;
      
        UPDATE Scux_Sie_Ar_Apply_Iface
           SET Scux_Process_Status  = Gv_Error
              ,Scux_Process_Message = Xv_Ret_Message
              ,Scux_Process_Date    = SYSDATE
              ,Last_Update_Date     = SYSDATE
              ,Last_Updated_By      = Fnd_Global.User_Id
         WHERE Scux_Session_Id = Pn_Scux_Session_Id;
        RAISE Fnd_Api.g_Exc_Error;
      END IF;
    
    END IF;
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Fnd_Exception.Handle_Exception(Pv_Api         => Lv_Api
                                         ,Xv_Ret_Status  => Xv_Ret_Status
                                         ,Xv_Ret_Message => Xv_Ret_Message);
  END Do_Submit_Process;

  /*===============================================================
  Program Name:   Do_Import
  Author      :   SIE ����
  Created:    :   2018-07-01
  Purpose     :   ���������Ʊ����API
  Parameters  :
              Pt_Iface_Tbl         IN Scux_Sie_Gl_Journal_Tbl --�ռ�������Ϣ
              Pv_Scux_Source_Code  IN VARCHAR2 --������Դ
              Pv_Synchro_Flag      IN VARCHAR2 --ͬ�������첽���÷�ʽ
              Pv_Init_Flag         IN VARCHAR2 --��Χϵͳ������Ҫ��ʼ������
              Pv_Language          IN VARCHAR2 --����
  Return  :
              Xn_Scux_Session_Id   OUT NUMBER  --����ID
              Xv_Ret_Status        OUT VARCHAR2--״̬
              Xv_Ret_Message       OUT VARCHAR2--������Ϣ
  Description: ���������Ʊ����API
      
  Update History
  Version    Date         Name            Description
  --------  ----------  ---------------  --------------------
  V1.0      2018-09-25    SIE ����         Creation    
  V1.1      2018-12-16    SIE ����         ����Ƿ��ʼ������
  V1. 2       2019-03-12    SIE�ſ�ӯ      Do_Import�������Pv_Created_by������Scux_Sie_Interface_Pkg.Get_Created_By(P
  ===============================================================*/
  PROCEDURE Do_Import(Pt_Iface_Tbl        IN Scux_Sie_Ar_Apply_Tbl
                     ,Pv_Scux_Source_Code IN VARCHAR2
                     ,Pv_Synchro_Flag     IN VARCHAR2 DEFAULT 'Y' -- �Ƿ�ͬ������
                     ,Pv_Init_Flag        IN VARCHAR2 DEFAULT 'Y' --�Ƿ��ʼ������
                     ,Pv_Language         IN VARCHAR2 DEFAULT 'ZHS'
                     ,Xn_Scux_Session_Id  OUT NUMBER
                     ,Xv_Ret_Status       OUT VARCHAR2
                     ,Xv_Ret_Message      OUT VARCHAR2
                     ,Pv_Created_By       IN VARCHAR2 DEFAULT NULL --V1.2 MOD
                      ) IS
    Lv_Procedure_Name VARCHAR2(30) := 'Do_Import';
    Lv_Api            VARCHAR2(100) := Gv_Package_Name || '.' ||
                                       Lv_Procedure_Name;
  
    Lv_Step VARCHAR2(240);
  
    Ln_Count      NUMBER := 0;
    Lv_Request_Id NUMBER;
  
  BEGIN
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_Begin);
  
    Scux_Sie_Interface_Pkg.Set_Language(Pv_Language);
  
    Xn_Scux_Session_Id := Scux_Sie_Interface_Pkg.Get_Session_Id;
  
    --V1.2    ADD  START --
    Gn_User_Id := Scux_Sie_Interface_Pkg.Get_Created_By(Pv_Created_By);
    --V1.2     ADD    END ---
    Scux_Fnd_Log.Step(Lv_Api
                     ,'1.Check_Parameter��-------------');
    Validate_Data(Pt_Iface_Tbl        => Pt_Iface_Tbl
                 ,Pv_Scux_Source_Code => Pv_Scux_Source_Code
                 ,Xv_Ret_Status       => Xv_Ret_Status
                 ,Xv_Ret_Message      => Xv_Ret_Message);
    Scux_Fnd_Exception.Raise_Exception(Pv_Ret_Status  => Xv_Ret_Status
                                      ,Pv_Ret_Message => Xv_Ret_Message);
  
    Scux_Fnd_Log.Step(Lv_Api
                     ,'2.Insert Date��-------------');
    Do_Insert_Process(Pt_Iface_Tbl        => Pt_Iface_Tbl
                     ,Pn_Scux_Session_Id  => Xn_Scux_Session_Id
                     ,Pv_Scux_Source_Code => Pv_Scux_Source_Code
                     ,Xn_Count            => Ln_Count
                     ,Xv_Ret_Status       => Xv_Ret_Status
                     ,Xv_Ret_Message      => Xv_Ret_Message);
    Scux_Fnd_Exception.Raise_Exception(Pv_Ret_Status  => Xv_Ret_Status
                                      ,Pv_Ret_Message => Xv_Ret_Message);
    ---------------------------------------------------------------------
  
    IF Ln_Count > 0 THEN
      --ͬ�����첽�����տ������Ʊ����ӿ�
      Scux_Fnd_Log.Step(Lv_Api
                       ,'3.Submit_Process��-------------');
      Do_Submit_Process(Pn_Scux_Session_Id  => Xn_Scux_Session_Id
                       ,Pv_Scux_Source_Code => Pv_Scux_Source_Code
                       ,Pv_Synchro_Flag     => Pv_Synchro_Flag
                       ,Pv_Init_Flag        => Pv_Init_Flag --V1.1 ADD
                       ,Xv_Ret_Status       => Xv_Ret_Status
                       ,Xv_Ret_Message      => Xv_Ret_Message);
      Scux_Fnd_Exception.Raise_Exception(Pv_Ret_Status  => Xv_Ret_Status
                                        ,Pv_Ret_Message => Xv_Ret_Message);
    ELSE
      --xv_Ret_Status := 'û����Ҫ�ύ������';
      Xv_Ret_Status  := Fnd_Api.g_Ret_Sts_Error;
      Xv_Ret_Message := Scux_Fnd_Message.Get_Messages(Pv_Application_Code => 'SQLGL'
                                                     ,Pv_Message_Name     => 'GL_COA_SVI_DATA_NOT_PASSED' --API û���ҵ�Ҫ��������ݡ�
                                                      );
      Scux_Fnd_Exception.Raise_Error(Pv_Api     => Lv_Api
                                    ,Pv_Status  => Xv_Ret_Status
                                    ,Pv_Message => Xv_Ret_Message);
    END IF;
  
    Xv_Ret_Status := Fnd_Api.g_Ret_Sts_Success;
    Scux_Fnd_Log.Event(Lv_Api
                      ,Lv_Procedure_Name || Scux_Fnd_Log.Gv_End);
  EXCEPTION
    WHEN OTHERS THEN
      Scux_Fnd_Exception.Handle_Exception(Pv_Api         => Lv_Api
                                         ,Xv_Ret_Status  => Xv_Ret_Status
                                         ,Xv_Ret_Message => Xv_Ret_Message);
    
  END Do_Import;
END Scux_Sie_Ar_Apply_Api_Pkg;
/
