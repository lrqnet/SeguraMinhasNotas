# Segurança

Relate vulnerabilidades de forma privada ao mantenedor antes de abrir uma issue pública.

## Modelo de dados

- O corpo das notas locais usa AES-GCM.
- A chave aleatória de 256 bits fica no Keychain e não é sincronizável.
- Títulos, tags e metadados de ciclo de vida permanecem visíveis no arquivo local para indexação e recuperação.
- Arquivos `.seguranota` usados na sincronização por pasta são portáveis e não criptografados.
- A autenticação opcional usa `LocalAuthentication`; o app recebe apenas o resultado da política do sistema.
- Atualizações usam Sparkle e devem ser publicadas com Apple Code Signing e, preferencialmente, assinatura EdDSA.

O SeguraMinhasNotas não inclui telemetria, analytics ou crash reporting. As únicas conexões de rede previstas são as verificações de atualização contra o appcast configurado; a sincronização de notas ocorre pela pasta escolhida pelo usuário.
