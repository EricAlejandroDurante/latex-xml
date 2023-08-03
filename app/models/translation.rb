class Translation
  include ActiveModel::API

  attr_accessor :txt_file, :xml_file, :error, :translated_file_path

  validates :txt_file, :xml_file, presence: true
  validate :verify_file_formats

  def translate
    return unless valid?

    data = read_txt_format(txt_file)
    xml_doc = Nokogiri::XML(File.open(xml_file.path))
    xml_doc_wc = translation_to_xml(xml_doc, data)
    latex_code_string = clearning_xml(xml_doc_wc)
    tempfile = Tempfile.new('archivo', encoding: 'UTF-8')
    latex_coding = "\\documentclass{article}
    \\usepackage[utf8]{inputenc}
    \\usepackage{amsmath}
    \\usepackage{ amssymb }
    \\title{Latex generator}
    \\author{Informe Ánalsis Forense}
    \\date{21/06/2023}
    \\begin{document}
    \\maketitle
    #{latex_code_string}
    \\end{document}
    "

    tempfile.write(latex_coding)
    # tempfile.write(latex_coding)
    tempfile.close

    value = system('pdflatex', '-halt-on-error', tempfile.path)
    if value
      puts "El archivo es #{File.basename(tempfile.path)}.tex"
      self.translated_file_path = "#{File.basename(tempfile.path)}.pdf"
      true
    else
      file_error = `pdflatex -halt-on-error #{tempfile.path}`
      regex_scan_error = /!(.*)!  ==>/m
      self.error = file_error.scan(regex_scan_error)[0][0].split("\nl.")
      false
    end
  end

  private
  def verify_file_formats
    if xml_file.content_type != 'text/xml'
      [true, 'Incorrect XML format']
    elsif txt_file.content_type != 'text/plain'
      [true, 'Incorrect TEXT plain format']
    end
  end

  def read_txt_format(file)
    # Abrir el archivo y leer todas las líneas en un arreglo
    lines = File.readlines(file)
    # Inicializar un diccionario vacío
    datos = {}
    # Iterar sobre cada línea y agregarla al diccionario
    lines.each do |line|
      nombre, edad = line.chomp.split(':')
      datos[nombre] = edad
    end
    datos
  end

  def translation_to_xml(xml_doc, datos)
    # Get all tags
    root_tag = xml_doc.xpath('//dump')

    # Get son tags
    tags_hijos = root_tag.children

    # Convertir a string
    xml_string = tags_hijos.to_xml

    # Recorremos cada valor del archivo a traducir
    # Llave corresponde al nombre del tag y valor su traduccion
    # llave:valor
    # Book:\section{book}
    datos.each do |llave, valor|
      # Regex para encontrar los tags
      regex_ruby = /<\s{0,}#{llave}[^>]*>/
      # Si incluye el $ toma el valor del tag y los transforma
      if valor.include?('$')
        # regex money sign
        # Es decir si esta el tag <name>Eric</name>
        # nos queda como: <name>Eric
        regex_money = %r{(<\s{0,}#{llave}[^>]*>[^<>]*)</\s{0,}#{llave}[^>]*>}

        # Encontrar los matches con el valor del tag
        # Es decir una lista con todos los elementos
        # [["<Genre id=\"1\">Computer"], ["<Genre id=\"2\">Fantasy"]]
        replace_tag = xml_string.scan(regex_money)

        # Encontrar el tag con su valor
        # Ejemplo <name>Eric</name>
        # Result: Eric
        tag_value = tags_hijos.css(llave)

        # Reemplazamos cada signo $ por el signo que le corresponde
        # Luego de eso
        replace_tag.each do |elemento|
          # puts "#{elemento}, #{tag_value[0].content}"
          valor_aux = valor
          new_value = valor_aux.gsub('$', tag_value[0].content)
          # puts "El nuevo valor es: #{new_value}"
          xml_string = xml_string.gsub(elemento.first, new_value)
        end
        next

      # Si incluye el # toma los atributos del tag y los transforma
      elsif valor.include?('#')
        # Encuentra todos los elementos con un nombre específico
        elements = xml_doc.xpath("//#{llave}")
        puts "La wea #{elements}"
        # Valores <tag atribute="Value"> a reemplazar
        replace_tag = xml_string.scan(regex_ruby)
        # Definiendo una variable para encontrar el valor del atributo
        n = 0
        # Itera sobre los elementos encontrados
        elements.each do |element|
          # Imprimimos el valor del tag a reemplazar
          puts "El valor del tag a reemplazar es: #{replace_tag[n]}"
          # Accede a los atributos o contenido de los elementos según sea necesario
          attribute_value = element.attribute('id').value
          puts "Element is: #{element}"
          # Realiza cualquier acción necesaria con los elementos encontrados
          puts "Atributo attribute_name: #{attribute_value}"
          # vemos el valor a reemplazar \section {bk102d} \n \begin{itemize}
          replace_id = valor.gsub(/#[a-zA-Z0-9_]+/, attribute_value)
          xml_string = xml_string.gsub(replace_tag[n], replace_id)
          n += 1
        end
        next
      end
      # puts tag_value
      # Encontrando el tag en archivo xml
      # por ejemplo encontrar todos los tags <book>
      # <book id="1">
      # <book id="2">
      replace_tag = xml_string.scan(regex_ruby)

      # En esta iteracion iremos cambiando el valor de la etiqueta y el codigo latex
      # por ejemplo:
      # <book id="aja"> por \section{book} \n \begin{itemize}
      # por eso esta la iteracion
      replace_tag.each do |element|
        xml_string = xml_string.gsub(element, valor)
        # puts "el elemento es #{element} y su valor es: #{valor}"
      end
    end
    xml_string.gsub('\n', "\n")
  end

  def clearning_xml(xml_string)
    # Limpiando el archivo de los tags que no fueron usados
    # Para todos los tags que esten <name>Pedro</name>
    regex_complete_clean = %r{<[A-Za-z]*[^<>]*>[^<>\\]*</[^<>]*>}
    regex_tag_clean = /<[A-Za-z]*[^<>\\]*>/
    replace_tag = xml_string.scan(regex_complete_clean)
    replace_tag.each do |elemento|
      # puts "Tags completos: #{elemento}"
      xml_string = xml_string.gsub(elemento, '')
    end
    replace_tag = xml_string.scan(regex_tag_clean)
    replace_tag.each do |elemento|
      # puts "Tags solos #{elemento}"
      xml_string = xml_string.gsub(elemento, '')
    end
    xml_string
  end
end
