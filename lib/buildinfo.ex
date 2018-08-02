defmodule BuildInfo do
  defmacro __using__(_) do
    info = get_build_info()
    quote do
      def build_info do
        unquote(info)
      end
    end
  end

  defp get_build_info do
    {hash, 0} = System.cmd("git", ~w(log -1 --format=%h,%cd,%an HEAD))
    {{y, m, d}, {h, min, s}} = :calendar.universal_time
    t_s = &Integer.to_string/1
    now = (
      t_s.(y) <> "-" <> t_s.(m) <> "-" <> t_s.(d) <> " " <>
        t_s.(h) <> ":" <> t_s.(min) <> ":" <> t_s.(s)
    )
    String.trim(hash) <> "@" <> now <> " UTC"
  end
end
