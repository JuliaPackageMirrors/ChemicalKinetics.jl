isempty(line::String) = !ismatch(r"[^\s\t\n\r]+", line)

iscomment(line::String) = ismatch(r"^#", line)

istitle(line::String) = ismatch(r"^\*\*\*(.*)MODEL (STATES|PARAMETERS|ODES)", line)

is_ode_name(name::String) = ismatch(r"^d/dt\((.*)\)$", name)

function get_title_type(line::String)
  if ismatch(r"^\*\*\*(.*)MODEL STATES(.*)", line)
    return "state"
  elseif ismatch(r"^\*\*\*(.*)MODEL PARAMETERS(.*)", line)
    return "parameter"  
  elseif ismatch(r"^\*\*\*(.*)MODEL ODES(.*)", line)
    return "ode"
  else
    throw(ParseError("Unknown title \""*line*"\" type in model specification"))
  end
end

function parse_line(line::String, linetype::String, model::OdeModel)  
  if linetype == "state"
    nTokens = parse_state_line(line, model.states)
  elseif linetype == "parameter"
    nTokens = parse_parameter_line(line, model.parameters)
  elseif linetype == "ode"
    nTokens = parse_ode_line(line, model.odes)
  else
    throw(ParseError("Unknown title \""*line*"\" type in model specification"))
  end
  
  return nTokens
end

function parse_state_line(line::String, dict::Dict{String, Float64})
  tokens = split(line, '=')
  nTokens = length(tokens)
  
  if nTokens != 2
    throw(ParseError("Line \""*line*"\" has wrong format"))
  end

  name, value = [strip(i) for i in tokens]  
  
  haskey(dict, name) ? throw(KeyError("\""*name*"\" specified more than once")) : (dict[name] = float64(value))
  
  return nTokens
end

function parse_parameter_line(line::String, dict::Dict{String, Float64})
  tokens = split(line, '=')
  nTokens = length(tokens)
  
  if nTokens == 1
    dict[strip(tokens)] = NaN
  elseif nTokens == 2
    name, value = [strip(i) for i in tokens]  
  
    haskey(dict, name) ? throw(KeyError("\""*name*"\" specified more than once")) : (dict[name] = float64(value))
  else
    throw(ParseError("Line \""*line*"\" has wrong format"))    
  end
  
  return nTokens  
end

function parse_ode_line(line::String, dict::Dict{String, NSE})
  tokens = split(line, '=')
  nTokens = length(tokens)
  
  if nTokens != 2
    throw(ParseError("Line \""*line*"\" has wrong format"))
  end

  name, value = [strip(i) for i in tokens]

  is_ode_name(name) ? (name = name[6:end-1]) : throw(KeyError("Time derivative \""*name*"\" has wrong format"))
  
  haskey(dict, name) ? throw(KeyError("\""*name*"\" specified more than once")) : (dict[name] = parse(value))
  
  return nTokens
end

function parse_model(file::String)
  odeModel = OdeModel(file, Dict{String, Float64}(), Dict{String, Float64}(), Dict{String, NSE}())

  s = open(file)

  while !eof(s)
    line = readline(s)
    if isempty(line) || iscomment(line)
      continue
    elseif istitle(line)
      title = get_title_type(line)
    else
      parse_line(line, title, odeModel)
    end
  end
  
  close(s)
  
  if sort(collect(keys(odeModel.states))) != sort(collect(keys(odeModel.odes)))
    throw(KeyError("States and their time derivatives in the ODE model are inconsistent"))
  end
  
  return odeModel
end
