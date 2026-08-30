import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private var pages: [(title: String, subtitle: String, icon: String, color: NoteColor)] { [
        (L10n.tr("Suas notas esperam na borda"), L10n.tr("Em repouso, apenas pequenos traços coloridos ficam visíveis. Leve o cursor até eles quando precisar."), "sidebar.right", .sky),
        (L10n.tr("Um gesto abre o baralho"), L10n.tr("As notas se espalham em cascata. Passe sobre uma aba para espiar ou clique para escrever."), "rectangle.stack", .mint),
        (L10n.tr("Escreva onde ela já está"), L10n.tr("A nota vira um editor flutuante e salva 250 ms depois de você parar de digitar."), "square.and.pencil", .sun),
        (L10n.tr("Arquive sem perder"), L10n.tr("⌥⌘A reúne tudo; ⌥⌘L abre o arquivo; ⌥⌘N cria uma nota de qualquer lugar."), "archivebox", .lilac)
    ] }

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(pages[page].color.color)
                    .frame(width: 300, height: 190)
                    .rotationEffect(.degrees(page.isMultiple(of: 2) ? -2 : 2))
                    .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
                Image(systemName: pages[page].icon)
                    .font(.system(size: 66, weight: .thin))
                    .foregroundStyle(SeguraNotasStyle.ink)
            }

            VStack(spacing: 10) {
                Text(pages[page].title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(pages[page].subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 470)
            }

            HStack(spacing: 7) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? SeguraNotasStyle.ink : Color.black.opacity(0.14))
                        .frame(width: index == page ? 22 : 7, height: 7)
                }
            }

            HStack {
                if page > 0 {
                    Button(L10n.tr("Voltar")) { withAnimation { page -= 1 } }
                        .buttonStyle(SeguraNotasButtonStyle())
                }
                Spacer()
                Button(L10n.tr(page == pages.count - 1 ? "Criar minha primeira nota" : "Continuar")) {
                    if page == pages.count - 1 { onFinish() }
                    else { withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { page += 1 } }
                }
                .buttonStyle(SeguraNotasButtonStyle(emphasized: true))
            }
            .padding(.horizontal, 50)
            .padding(.bottom, 34)
        }
        .frame(width: 650, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
