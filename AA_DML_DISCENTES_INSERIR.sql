WITH RECURSIVE UNIDADES_FILHAS(ID_UNIDADE) AS ( 
 SELECT ID_UNIDADE, ID_CAMPUS_IES  
 FROM COMUM.UNIDADE 
 WHERE ID_UNIDADE IN (SELECT ID_UNIDADE FROM COMUM.UNIDADE U WHERE U.ID_CAMPUS_IES IS NOT NULL AND U.NOME LIKE 'CAMPUS%')
 UNION ALL 
 SELECT U.ID_UNIDADE, U.ID_CAMPUS_IES 
 FROM COMUM.UNIDADE U, UNIDADES_FILHAS UF 
 WHERE U.ID_UNID_RESP_ORG = UF.ID_UNIDADE 
 )   
SELECT distinct
  D.ID_PESSOA 								AS S_ID_PESSOA,
  D.ID_DISCENTE 							AS S_ID_DISCENTE, 
  C.ID_UNIDADE 								AS S_UNIDADE, 
  C.ID_CURSO 								AS S_CURSO, 
  null                                      as S_CPF_RESPONSAVEL,
  null 										as S_NUMERO_NIS_RESPONSAVEL,
  P.NOME_MAE 								AS S_NOME_MAE_ESTUDANTE,
  LPAD(P.CPF_CNPJ::TEXT, 11, '0') 			AS S_CPF_SIG_DB, 
  P.NOME 									AS S_NOME,      
  TO_CHAR(P.DATA_NASCIMENTO, 'DD/MM/YYYY') 	AS S_DATA_NASCIMENTO,
  TO_CHAR(P.DATA_NASCIMENTO, 'YYYY-MM-DD') 	AS S_DATA_NASCIMENTO_JSON,
case
	when P.SEXO = 'M' then 1
        when P.sexo = 'F' then 2
	else 0
 end									AS S_GENERO, 
  P.ID_RACA 								AS S_RACA_COR,
  P.EMAIL									as S_EMAIL,
  P.TELEFONE 								AS S_TELEFONE, 
  null 										as S_NUMERO_NIS,
  null                                      as S_CERTIDAO_NASCIMENTO,
  null                                 		as S_CNH,
  P.NUMERO_IDENTIDADE 						AS S_RG,
  UPPER(P.ORGAO_EXPEDICAO_IDENTIDADE) 		AS S_ORGAO_EMISSOR,
  UPPER(E.LOGRADOURO) 						AS S_LOGRADOURO,
  UPPER(E.BAIRRO) 							AS S_BAIRRO,
  E.NUMERO 									AS S_NUMERO_END,
  replace(E.CEP,'-','')									AS S_CEP,
  M.NOME 									AS S_NOME_MUNICIPIO_END,
  UF.DESCRICAO 								AS S_UF_END, 
  UF.SIGLA 									AS S_UF_SIGLA_END,  
  null 										as S_DATA_FIM_OU_APROVACAO,
  case
	when TM.ID_SITUACAO_MATRICULA = 2 then 1
        else 0
  end                  AS S_SITUACAO_MATRICULA,
  EXTRACT(YEAR FROM NOW())::INT4 			AS S_SERIE_ANO,
  D.MATRICULA 								AS S_MATRICULA_REDE, 
  'CAMPUS ' || ci.nome                      as S_INSTITUICAO,
  CI.CODIGO_INEP  							AS S_INEP,
(select TO_CHAR(CA2.inicioperiodoletivo,'YYYY-MM-DD') 
		from COMUM.CALENDARIO_ACADEMICO ca2 
		where ((ca2.id_unidade = c.id_unidade and ca2.id_curso = c.id_curso) or
		  	  (ca2.id_unidade = c.id_unidade  and ca2.id_modalidade = c.id_modalidade_educacao) or
			  ca2.id_unidade = c.id_unidade)
		and ca2.ativo is true
		and ca2.periodo = 1
		and ca2.ano = 2024
		and ca2.nivel = 'G' limit 1) AS S_DATA_INICIO_PERIODO_LETIVO,   
   TO_CHAR(TM.DATA_MATRICULA,'YYYY-MM-DD') 	AS S_DATA_INICIO_MATRICULA,
   case 
  	when C.ID_TIPO_OFERTA_CURSO = 3 then 1 -- Anual
  	when C.ID_TIPO_OFERTA_CURSO = 4 then 2 -- Semestral
  	else null 	
  end   		AS S_FORMA_ORGANIZACAO_TURMA,
  0 as estudantePpl,
  cur.semestre_conclusao_ideal 				AS S_TURMA_ORAGANIZACAO_QUANTIDADE_TOTAL,
   case 
	when dg.ch_total_integralizada <= ((1/3::decimal(16,2))  * cur.ch_total_minima) then 1
	when dg.ch_total_integralizada <= ((2/3::decimal(16,2))  * cur.ch_total_minima) then 2
	when dg.ch_total_integralizada > ((2/3::decimal(16,2))  * cur.ch_total_minima) then 3
	else 0		
  end  										AS S_ESTUDANTE_EJA_ANO_PERIODO,  
 case
 	when gmc.id_turno = 4 then 1
 	else 0
 end AS S_ESTUDANTE_INTEGRAL
FROM CURSO C 
JOIN UNIDADES_FILHAS UFS
  ON UFS.ID_UNIDADE = C.ID_UNIDADE 
JOIN COMUM.CAMPUS_IES CI 
  ON CI.ID_CAMPUS = UFS.ID_CAMPUS_IES
JOIN DISCENTE D
ON D.ID_CURSO = C.ID_CURSO
left JOIN COMUM.CALENDARIO_ACADEMICO CA
  ON CA.ID_CURSO = D.ID_CURSO
  and ca.ativo is true
  and ca.periodo = 1
  and ca.ano = 2024
join graduacao.discente_graduacao dg 
ON DG.id_discente_graduacao = D.id_discente   
JOIN graduacao.matriz_curricular GMC
  on GMC.id_curso = d.id_curso 
 and DG.id_matriz_curricular = GMC.id_matriz_curricular 
 and gmc.id_campus = ci.id_campus 
join graduacao.curriculo cur    
  on cur.id_matriz = gmc.id_matriz_curricular   
 and cur.id_curriculo = d.id_curriculo
JOIN COMUM.PESSOA P
  ON P.ID_PESSOA = D.ID_PESSOA 
JOIN COMUM.ENDERECO E
  ON E.ID_ENDERECO = P.ID_ENDERECO_CONTATO  
JOIN COMUM.MUNICIPIO M
  ON P.ID_MUNICIPIO_NATURALIDADE = M.ID_MUNICIPIO
JOIN COMUM.UNIDADE_FEDERATIVA UF 
  ON M.ID_UNIDADE_FEDERATIVA = UF.ID_UNIDADE_FEDERATIVA 
JOIN (
  SELECT MC.ID_DISCENTE, 
  		 MC.ID_SITUACAO_MATRICULA,
  		MIN(MC.DATA_CADASTRO) AS DATA_MATRICULA
  FROM ENSINO.MATRICULA_COMPONENTE MC
  WHERE MC.ID_SITUACAO_MATRICULA = 2
  GROUP BY MC.ID_DISCENTE,  MC.ID_SITUACAO_MATRICULA
) AS TM
  ON TM.ID_DISCENTE = D.ID_DISCENTE
WHERE ( 
      C.ID_TIPO_CURSO_ACADEMICO in (4) -- TÉCNICO
      OR (
    C.ID_TIPO_CURSO_ACADEMICO IN(5, 6) -- (FORMAÇÃO INICIAL, FORMAÇÃO CONTINUADA)
    AND C.ID_OFERTA_CURSO_ACADEMICO IN (6,7) -- PROEJA
    )
  )
AND D.STATUS IN (1,2,8,9)
and length(replace(E.CEP,'-','')) = 8
order by p.nome;