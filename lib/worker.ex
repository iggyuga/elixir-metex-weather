defmodule Metex.Worker do
	use GenServer

	## Client API
	def start_link(opts \\ []) do
		GenServer.start_link(__MODULE__, :ok, opts)
	end

	def get_temperature(pid, location, temperature_option) do
		GenServer.call(pid, {:location, location, :temperature_option, temperature_option})
	end

	## Server Callbacks
	def init(:ok) do
		{:ok, %{}}
	end

	def handle_call({:location, location, :temperature_option, temperature_option}, _from, stats) do
		case temperature_of(location, temperature_option) do
			 {:ok, temp} ->
				IO.puts("ok in handle")
				new_stats = update_stats(stats, location)
				{:reply, "#{temp}*#{String.capitalize(temperature_option)}", new_stats}
			_ ->
				IO.puts("error in handle")
				{:reply, :error, stats}
				
		end
	end

	## Helper functions 

	defp temperature_of(location, temperature_option) do
		result = url_for(location)
		|> HTTPoison.get 
		|> parse_response(temperature_option)
		case result do
		 {:ok, temp} -> 
			{:ok, "#{location}: #{temp}*#{String.capitalize(temperature_option)}"}
		 :error ->
			 IO.puts("error in temp of")
			 "#{location} not found"
				
		end
	end

	defp url_for(location) do
		location = URI.encode(location)
		|> IO.inspect()
		"http://api.openweathermap.org/data/2.5/weather?q=#{location}&appid=#{apikey()}"
	end

	defp parse_response({:ok, %HTTPoison.Response{body: body, status_code: 200}}, option) do
		body 
		|> JSON.decode!
		|> compute_temperature(option)
	end

	defp parse_response(_, _) do
		:error
	end

	defp compute_temperature(json, option) do
		try do
			temp = convert(json["main"]["temp"], option) |> Float.round(2)
			{:ok, temp}
		rescue
			_ -> :error
		end
	end
 
	defp apikey() do
		"8536c81ebcb074abbe45452b799dec42"
	end

	defp update_stats(old_stats, location) do
		case Map.has_key?(old_stats, location) do
			true ->
				Map.update!(old_stats, location, &(&1 + 1))
			false ->
				Map.put_new(old_stats, location, 1)
		end
	end

	defp convert(temperature, option) do
		cond do 
			option in ["f", "F"] -> 
				temperature * (9/5) - 459.67
			option in ["c", "C"] ->
				temperature - 273.15
			true ->
				temperature
		end
	end
end