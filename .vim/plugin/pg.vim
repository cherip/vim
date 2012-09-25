
" A simple script go generate document for C/C++ function
" TODO: 1 like :  if (!doc) , not valid param info, fixed but param info like
"                 void  aaa(void), failed
" 
"        

if exists("loaded_gendocument")
    finish
endif
let loaded_gendocument = 1

let g:KeyWordsPrefixToErase = "inline,extern,\"C\",virtual,static,"
let g:TokenNotInFunDeclare = "#,{,},;,"
let g:MAX_PARAM_LINE = 12 

function! <SID>DateInsert()
	$read !date /T
endfunction

function! <SID>OpenNew()
	let s = input("input file name: ")
	execute  ":n"." ".s
endfunction


" Function : GetNthItemFromList (PRIVATE)
" Purpose  : Support reading items from a comma seperated list
"            Used to iterate all the extensions in an extension spec
"            Used to iterate all path prefixes
" Args     : list -- the list (extension spec, file paths) to iterate
"            n -- the extension to get
" Returns  : the nth item (extension, path) from the list (extension 
"            spec), or "" for failure
" Author   : Michael Sharpe <feline@irendi.com>
" History  : Renamed from GetNthExtensionFromSpec to GetNthItemFromList
"            to reflect a more generic use of this function. -- Bindu
function! <SID>GetNthItemFromList(list, n, sep) 
   let itemStart = 0
   let itemEnd = -1
   let pos = 0
   let item = ""
   let i = 0
   while (i != a:n)
      let itemStart = itemEnd + 1
      let itemEnd = match(a:list, a:sep, itemStart)
      let i = i + 1
      if (itemEnd == -1)
         if (i == a:n)
            let itemEnd = strlen(a:list)
         endif
         break
      endif
   endwhile 
   if (itemEnd != -1) 
      let item = strpart(a:list, itemStart, itemEnd - itemStart)
   endif
   return item 
endfunction


function! DebugStr(s)
	return
	echo a:s
endfunction

function! <SID>MatchInList(s, l)
	let i=1
	let kw = <SID>GetNthItemFromList(a:l, i, ",")
	while (strlen(kw)>0)
		call DebugStr("MatchInList Nth ".kw)
		if (match(a:s, kw)!=-1)
			return i
		endif
		let i = i+1
		let kw = <SID>GetNthItemFromList(a:l, i, ",")
	endwhile
	return -1
endfunction


function! <SID>ErasePrefix(s)
	let i=1 
	let ts = substitute(a:s, '^\s\+', "", "")  		
	let kw = <SID>GetNthItemFromList(g:KeyWordsPrefixToErase, i, ",")

	while (strlen(kw)>0)
		call  DebugStr("ErasePrefix Nth ".kw)
		let ts = substitute(ts, '^'.kw, "", "")  	
		let ts = substitute(ts, '^\s\+', "", "")  		
		let i = i+1
		let kw = <SID>GetNthItemFromList(g:KeyWordsPrefixToErase, i, ",")
	endwhile
	return ts
endfunction

function! <SID>GetCurFunction()
	let cur_line_no = line(".")
	let max_line_no = line("$")
	let fun_str = ""
	let raw_fun_str = ""
	let fun_line_count=0

	while (fun_line_count<g:MAX_PARAM_LINE && cur_line_no<=max_line_no)
		let cur_line = getline(cur_line_no)
		let cur_line_no = cur_line_no + 1
		let fun_line_count = fun_line_count+1
		if ( strlen(cur_line)>0 )
			let raw_fun_str = raw_fun_str . cur_line . " \n"
		endif
	endwhile

	call DebugStr("raw_fun_str ".raw_fun_str)

	let idx =0
	let fun_over=0
	let raw_fun_str_len = strlen(raw_fun_str)
	let quote=0
	while (idx<raw_fun_str_len && fun_over==0)
		let cur_char = raw_fun_str[idx]
		"exec DebugStr("cur_char:".cur_char)
		let idx = idx+1

		if (cur_char=="/")
			"check next char
			let next_char = raw_fun_str[idx]
			"exec DebugStr("next_char:".next_char)
					
			if (next_char=="/") 
				"find /n
				let new_line_pos = match(raw_fun_str, "\n", idx)
				if (new_line_pos==-1)
					"echo "error format near //"
					return ""	
				endif
				let idx = new_line_pos+1
				continue
			elseif (next_char=="*")
				let idx = idx+1
				let right_pos = match(raw_fun_str, "*/", idx)
				if (right_pos==-1)
					 "error format near /*"
					return ""	
				endif
				let idx = right_pos+2
				continue	
			else
				 "error format near /"
				return ""
			endif
		endif

		if (cur_char=="(")
			let quote = quote+1
		endif

		if (cur_char==")")
			let quote = quote-1
			if (quote==0)
				let fun_over=1
			endif
		endif

		if (cur_char!="\n")
			let fun_str = fun_str . cur_char
		endif
		"exec DebugStr(fun_str)	
	endwhile


	if (fun_over==1)
		if ( <SID>MatchInList(fun_str, g:TokenNotInFunDeclare)==-1)
			return <SID>ErasePrefix(fun_str)
		endif
	endif

	 "can't find function format!"
	return ""
	
endfunction
	

"pass in : ' int a[23] '
"return  : "int[23],a"
function! <SID>GetSingleParamInfo(s, isparam)
	" unsigned int * ass [1][2]
	
	let single_param = a:s
	call DebugStr("single param ".single_param)
	

	if (a:isparam)
		" erase default value , eg int a = 10
		let single_param = substitute(single_param, '=\(.\+\)', "", "g")  
	endif
	
	" erase ending blank
	let single_param = substitute(single_param, '\(\s\+\)$' , "", "")
	
	" erase blank before '['
	let single_param = substitute(single_param, '\(\s\+\)[', "[", "g")  
	"exec DebugStr(single_param)

	let single_param = substitute(single_param, '^\s\+', "", "")  
	"exec DebugStr(single_param)

	" erase blank before '*' | '&'
	let single_param = substitute(single_param, '\(\s\+\)\*', "*", "g")  
	let single_param = substitute(single_param, '\(\s\+\)&', "\\&", "g")  
	"exec DebugStr(single_param)

	" insert blank to * (&), eg int *i => int * i
	let single_param = substitute(single_param, '\(\*\+\)', "\\0 ", "")  
	let single_param = substitute(single_param, '\(&\+\)', "\\0 ", "")  
	
	call DebugStr("single param processed:" .single_param. "END")
	"call DebugStr("single param processed:" .single_param)

	"let match_res = matchlist(single_param, '\(.\+\)\s\+\(\S\+\)')
	"'^\s/*\(.\+\)\s\+\(.\+\)\s/*$')     
	"exec DebugStr(match_res)
	"let type = match_res[1]
	"let name = match_res[2]
	
	let pos = match(single_param, '\S\+$')
	
	if (pos==-1)
		call DebugStr("pos==-1")
		return ""
	endif

	let type = strpart(single_param, 0, pos-1)
	let name = strpart(single_param, pos)
	
	" type can be "", eg c++ constructor
	if (strlen(name)==0)
		call DebugStr("strlen(name)==0")
		return ""
	endif
	
	if (a:isparam && strlen(type)==0)
		call DebugStr("a:isparam && strlen(type)==0")
		return ""
	endif	

	let bpos = match(name, "[")
	if (bpos!=-1)
		let type = type . strpart(name, bpos)
		let name = strpart(name, 0, bpos)
	endif

	"trim final string
	let type = substitute(type, '\(\s\+\)$' , "", "")
	let name = substitute(name, '\(\s\+\)$' , "", "")
	
	let ret = type.",". name.","
	call DebugStr("RET GetSingleParamInfo " . ret)	
	return ret
endfunction


" format are "type,name,"
"  begin with function name and then "\n" then followed by param
function! <SID>GetFunctionInfo(fun_str)
	let param_start = match(a:fun_str, "(")
	let fun_info = ""
	
	if (param_start==-1) 
		  "can't find '(' in function "
		return ""
	endif

	let fun_name_part = strpart(a:fun_str, 0, param_start)
	let param_start = param_start + 1
	let param_len   = strlen(a:fun_str) - param_start -1
	let fun_param_part = strpart(a:fun_str, param_start, param_len)
       	
	call DebugStr("FUN :".fun_name_part)
	call DebugStr("PARAM :".fun_param_part)
	
	"analysis fun_name_part
	let temp = <SID>GetSingleParamInfo(fun_name_part, 0)
	if (strlen(temp)==0)
		 "function name analysis failed!!"
		return ""
	endif
	let fun_info = fun_info . temp

	"analysis fun_param_part
	let cur_idx = 0
	let comma_idx = match(fun_param_part, "," , cur_idx)
	while (comma_idx!=-1) 
		"for earch param
		let single_param = strpart(fun_param_part, cur_idx, comma_idx - cur_idx)	
		let temp = <SID>GetSingleParamInfo(single_param, 1)
		if (strlen(temp)>0)
			let fun_info = fun_info.temp
			let cur_idx = comma_idx + 1
			let comma_idx = match(fun_param_part, "," , cur_idx)
		else
			echo "function param analysis failed!!"
			return ""
		endif
	endwhile
       	
	"last param
	let single_param = strpart(fun_param_part, cur_idx)

	if (strlen(matchstr(single_param, '\S'))>0)
		let temp = <SID>GetSingleParamInfo(single_param, 1)
		if (strlen(temp)>0)
			let fun_info = fun_info.temp
		"else 
			"echo "function param analysis failed!!"
		"	return ""
		endif

	endif	
	
	return fun_info
endfunction


function! <SID>GetUserName()
	let home = $HOME
	let user = matchstr(home, '[^/\\]\+$')
	return user
endfunction

function! <SID>GetDate()
	"windows
	let date = system("date /T")
	if (v:shell_error!=0)
		"linux
		let date = system("date +%x\" \"%T")
	endif

	if (date[strlen(date)-1]=="\n")
		let date = strpart(date, 0, strlen(date)-1)
	endif
	return date
endfunction
 
function! <SID>GetDoxygenFileStyleDoc(fun_info, leading_blank, file_name)

	let doc=""
	let idx=1
	
	let ret_type = <SID>GetNthItemFromList(a:fun_info, idx, ",")
	let idx = idx + 1

	"gen function name part
	let type = <SID>GetNthItemFromList(a:fun_info, idx, ",")
	let idx = idx + 1
	let name = <SID>GetNthItemFromList(a:fun_info, idx, ",")
	let idx = idx + 1

	let doc = doc . a:leading_blank."/**"."\n"
	let doc = doc . a:leading_blank." *  ============================================================="."\n"
	let doc = doc . a:leading_blank." *"."\n"
	let doc = doc . a:leading_blank." *  Copyright (c) 2011-2012 Panguso.com. All rights reserved."."\n"
	let doc = doc . a:leading_blank." *"."\n"
	let doc = doc . a:leading_blank." *      FileName:  " . a:file_name . "\n"
	let doc = doc . a:leading_blank." *   Description:  Fuck the world" . "\n"
	let doc = doc . a:leading_blank." *       Created:  " . <SID>GetDate() . "\n"
	let doc = doc . a:leading_blank." *       Version:  " . "\n"
	let doc = doc . a:leading_blank." *      Revision:  #1;#4" . "\n"
	let doc = doc . a:leading_blank." *        AUTHOR:  " . <SID>GetUserName() ."(".<SID>GetUserName()."@panguso.com)"."\n"
	let doc = doc . a:leading_blank." *"."\n"
	let doc = doc . a:leading_blank." *  ============================================================="."\n"
	let doc = doc . a:leading_blank."**/"."\n"

	return doc
endfunction


function! <SID>GenFileDoc()
	let cur_line = line(".")
       	"let first_line = expand("%:t")
       	let first_line = getline(cur_line)
	let leading_blank = ""

	"if (strlen(matchstr(first_line, '\S'))==0)
	"	return
	"else 
	"	let leading_blank = matchstr(first_line, '\(\s*\)')
	"endif 

	"let fun_str = <SID>GetCurFunction()
	let file_str = expand("%:t")
	if (strlen(file_str)==0) 
		"exec cursor(cur_line, 0)
		return
	endif

	call DebugStr("FUN_BODY ".file_str)

	let fun_info = <SID>GetFunctionInfo(file_str)
	call DebugStr("fun_info ".fun_info."END")
	
	let doc = <SID>GetDoxygenFileStyleDoc(fun_info, leading_blank, file_str)
	"echo "doc \n".expand(doc)

	if (strlen(doc)>0)
		let idx =1
		let li = <SID>GetNthItemFromList(doc, idx, "\n")
		while (strlen(li)>0)
			call append( cur_line-1, li.expand("<CR>"))
			let idx = idx + 1
			let cur_line = cur_line + 1
			let li = <SID>GetNthItemFromList(doc, idx, "\n")
		endwhile
	endif
endfunction

function! <SID>GetDoxygenFuncStyleDoc(fun_info, leading_blank)

	let doc=""
	let idx=1
	
	let ret_type = <SID>GetNthItemFromList(a:fun_info, idx, ",")
	let idx = idx + 1
	let fun_name = <SID>GetNthItemFromList(a:fun_info, idx, ",")
	let idx = idx + 1
	if (strlen(fun_name)==0)
		return ""
	endif	

	"gen function name part
	let type = <SID>GetNthItemFromList(a:fun_info, idx, ",")
	let idx = idx + 1
	let name = <SID>GetNthItemFromList(a:fun_info, idx, ",")
	let idx = idx + 1

	let doc = doc . a:leading_blank."/**"."\n"
	let doc = doc . a:leading_blank." * **********************************************************"."\n"
	let doc = doc . a:leading_blank." *  @brief\t:  "."\n"
	let doc = doc . a:leading_blank." *"."\n"
	let doc = doc . a:leading_blank." *  @name\t:  " . fun_name . "\n"
	"gen param part
	while(strlen(type)>0 && strlen(name)>0)

		let doc = doc . a:leading_blank." *  @param\t:  [in/out]\t" . name . " : " . type . "\n"
		let type = <SID>GetNthItemFromList(a:fun_info, idx, ",")
		let idx = idx + 1
		let name = <SID>GetNthItemFromList(a:fun_info, idx, ",")
		let idx = idx + 1
	endwhile
	let doc = doc . a:leading_blank." *  @return\t:  ".ret_type."\n"
	let doc = doc . a:leading_blank." *  @retval\t:"."\n"
	let doc = doc . a:leading_blank." *  @todo\t:"."\n"
	let doc = doc . a:leading_blank." *"."\n"
	let doc = doc . a:leading_blank." *  @author\t:  " . <SID>GetUserName() ."\n"
	let doc = doc . a:leading_blank." *  @date\t:  " . <SID>GetDate() . "\n"
	let doc = doc . a:leading_blank." * **********************************************************"."\n"
	let doc = doc . a:leading_blank." **/"."\n"

	if (! (strlen(type)==0 && strlen(name)==0) )
		return ""
	endif

	return doc
endfunction
	

function! <SID>GenFuncDoc()
	let cur_line = line(".")
       	let first_line = getline(cur_line)
	let leading_blank = ""

	if (strlen(matchstr(first_line, '\S'))==0)
		return
	else 
		let leading_blank = matchstr(first_line, '\(\s*\)')
	endif 

	let fun_str = <SID>GetCurFunction()
	if (strlen(fun_str)==0) 
		"exec cursor(cur_line, 0)
		return
	endif

	call DebugStr("FUN_BODY ".fun_str)

	let fun_info = <SID>GetFunctionInfo(fun_str)
	call DebugStr("fun_info ".fun_info."END")
	
	let doc = <SID>GetDoxygenFuncStyleDoc(fun_info, leading_blank)
	"echo "doc \n".expand(doc)

	if (strlen(doc)>0)
		let idx =1
		let li = <SID>GetNthItemFromList(doc, idx, "\n")
		while (strlen(li)>0)
			call append( cur_line-1, li.expand("<CR>"))
			let idx = idx + 1
			let cur_line = cur_line + 1
			let li = <SID>GetNthItemFromList(doc, idx, "\n")
		endwhile
	endif
endfunction


map <F11> :call <SID>GenFuncDoc()<CR>
map <F12> :call <SID>GenFileDoc()<CR>
