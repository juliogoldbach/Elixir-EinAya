defmodule EinAya do

  def main() do
    core_ein_aya_url = "https://he.wikisource.org/wiki/%D7%A2%D7%99%D7%9F_%D7%90%D7%99%D7%94"
    body = get_request(core_ein_aya_url)
    IO.puts """
    Welcome to #{IO.ANSI.green <> "Elixir EinAya" <> IO.ANSI.reset}.
    """
    
    map = 
      get_user_massechet_input()
      |> get_massechet_url(body)
      |> get_request()
      |> get_perakim_or_piskaot()
      |> get_user_perek_piska_input(:perakim)
      |> get_request()
      |> get_perakim_or_piskaot()
      |> get_user_perek_piska_input(:piskaot)
      |> get_request()
      |> get_piska()

      map.piska
      #|> String.split(" ,")
      |> String.graphemes
      |> Enum.chunk_every(100)
      |> Enum.map(fn x -> Enum.join(x) end) 
      |> Enum.reverse

  end

  defp get_request(url) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        body
      {:ok, %HTTPoison.Response{status_code: 404}} ->
        raise "Error 404"
      {:error, %HTTPoison.Error{reason: reason}} ->
        raise reason
    end
  end

  defp get_massechet_url(user_input, body) do
      urls =
        body 
        |> Floki.find("a") 
        |> Floki.raw_html
        |> String.split("</a>")
        |> Enum.map(fn x -> x <> "</a>" end)
        |> Enum.filter(fn x -> Regex.match?(~r(title), x) end)
        |> get_url_and_title()

        # wasnt a easy time trying to make hebrew (foo$|bar$) regex, so:
      [berachot] = Enum.filter(urls, fn x -> Regex.match?(~r(עין איה/ברכות$), List.to_string(x.title)) end)
      [shabat] = Enum.filter(urls, fn x -> Regex.match?(~r(עין איה/שבת$), List.to_string(x.title)) end)
      [peah] = Enum.filter(urls, fn x -> Regex.match?(~r(עין איה/פאה$), List.to_string(x.title)) end)

      massechet_map = 
        Map.put(Map.new(), :berachot, berachot)
        |> Map.put(:shabat, shabat)
        |> Map.put(:peah, peah)

      Map.get(massechet_map, user_input).url
  end


  defp get_url_and_title(list) when is_bitstring(list), do: get_url_and_title([list])
  defp get_url_and_title(list) do
  
    Enum.map(list, fn x -> %{title:
                          Floki.attribute(x, "title"),
                          url:
                          Floki.attribute(x, "href") |> prepend_url_prefix()
                          } end)
  end


  defp prepend_url_prefix([url]) do
    "https://he.wikisource.org" <> url 
  end


  defp get_user_massechet_input() do
    prompt =
      """
      Time to pick your massechet.
      Type 1 for Berachot, 2 for Shabat or 3 for Peah
      """
    input = IO.gets(prompt) |> String.trim() |> String.to_integer()

    case input do
      1 -> :berachot
      2 -> :shabat
      3 -> :peah
      _ -> get_user_massechet_input()
    end
  end

  defp get_perakim_or_piskaot(body) do
    body 
    |> Floki.find("#mw-content-text")
    |> Floki.raw_html
    |> Floki.find("li")
    |> Floki.raw_html
    |> String.split("</li>")
    |> Enum.map(fn x -> x <> "</li>" end)
    |> Enum.map(fn x -> x |> Floki.find("a") |> Floki.raw_html end)
    |> Enum.filter(fn x -> Regex.match?(~r(title), x) end)
    |> get_url_and_title()
    |> Enum.filter(fn x -> is_map(x) end) 
    |> Enum.with_index() #indexing at the map. also line below
    |> Enum.map(fn {map, index} -> Map.put(map, :id, index + 1) end)

  end

  defp get_user_perek_piska_input(list, identifier) do
    string_identifier = Atom.to_string(identifier)
    list_length = Enum.count(list)
    prompt = 
    """
    There are #{list_length} #{string_identifier} at this massechet.
    Choose one.
    """

    user_input = IO.gets(prompt) |> String.trim() |> String.to_integer()

     case user_input do 
       n when n > 0 and n <= list_length ->
         n
       _ ->
         IO.puts("Invalid #{string_identifier} \n")
         get_user_perek_piska_input(list_length, identifier)
     end

     p_map = Enum.filter(list, fn map -> Map.get(map, :id) == user_input end) |> Enum.min()
     p_map.url
  end

  defp get_piska(body) do

    text =
      body
      |> get_whole_text()

    header = 
      body
      |> get_piska_header()

    # topic =
    #   text
    #   |> get_piska_topic()

    guemara =
      body
      |> get_piska_guemara()

    guemara_piece =
      text
      |> get_guemara_piece()

    piska =
      text
      |> get_piska_text()
    
    Map.merge(header, guemara)
    # |> Map.merge(topic)  # most piskaot have no topic
    |> Map.merge(guemara_piece)
    |> Map.merge(piska)

  end
  
  defp get_whole_text(body) do
    body
    |> Floki.find("#mw-content-text")
    |> Floki.raw_html
    |> Floki.find("p")
    |> Floki.raw_html
  end
  
  defp get_piska_header(body) do
    %{
      header:
        body
      |> Floki.find("#firstHeading")
      |> Floki.raw_html
      |> String.split("lang=\"he\">")
      |> Enum.filter(fn x -> Regex.match?(~r(עין איה), x) end)
      |> Enum.map(fn x -> Regex.replace(~r(</h1>), x, "") end)
      |> List.to_string
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.join()

    }  
  end


  # defp get_piska_topic(text) do
  #   %{topic:
  #     text
  #     |> String.split("</b></p>")
  #     |> Enum.min_by(fn x -> String.length(x) end)
  #     |> String.replace("<p><b>", "")
  #     |> String.graphemes()
  #     |> Enum.reverse()
  #     |> Enum.join()
  #   }
  # end

  defp get_piska_guemara(text) do
    [map] =  
      text
      |> Floki.find("small")
      |> Floki.raw_html
      |> Floki.find("a")
      |> Floki.raw_html
      |> get_url_and_title()

    guemara =
      map.title
      |> List.to_string()
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.join()

      %{guemara: guemara, guemara_url: map.url}
  end

  defp get_guemara_piece(body) do
    
    %{guemara_piece:
        body
      |> Floki.find(".mfrj")
      |> Floki.raw_html
      |> Floki.text()
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.join()
    }
  end

  defp get_piska_text(body) do
    %{piska:
      body
      |> Floki.text()
      |> String.split("\n")
      |> drop_first_and_last()
      |> Enum.map(fn x -> x |> String.graphemes() |> Enum.reverse() |> Enum.join() end)
      |> Enum.join()
    }
  end

  defp drop_first_and_last(list) do
    list
    |> Enum.drop(1)
    |> Enum.drop(-1)
  end


end
