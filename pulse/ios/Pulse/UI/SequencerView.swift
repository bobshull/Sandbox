import UIKit
import Combine

protocol SequencerViewDelegate: AnyObject {
    func sequencer(toggleStep trackId: String, step: Int)
}

/// Scrolling grid where each row pins its track header to the leading edge
/// while the cells scroll horizontally. All row scroll views share their
/// offset so they move in lockstep.
final class SequencerView: UIView, UIScrollViewDelegate, TrackHeaderViewDelegate {

    weak var delegate: SequencerViewDelegate?

    private let store: Store
    private let engine: AudioEngine
    private var cancellables = Set<AnyCancellable>()

    private let trackStack = UIStackView()
    private let headerRow = UIView()
    private let stepLabels: [UILabel]
    private var rows: [RowView] = []
    private var syncing = false

    private struct RowView {
        let track: Track
        let header: TrackHeaderView
        let scrollView: UIScrollView
        let cellStack: UIStackView
        var cells: [CellButton]
    }

    private let headerColumnWidth: CGFloat = 150
    private let cellSpacing: CGFloat = 3
    private let beatGap: CGFloat = 8

    init(store: Store, engine: AudioEngine) {
        self.store = store
        self.engine = engine
        self.stepLabels = (0..<Tracks.stepCount).map { i in
            let l = UILabel()
            l.text = "\(i + 1)"
            l.font = .monospacedSystemFont(ofSize: 10, weight: (i % 4 == 0) ? .bold : .regular)
            l.textColor = (i % 4 == 0) ? Theme.text : Theme.textFaint
            l.textAlignment = .center
            return l
        }
        super.init(frame: .zero)
        configure()
        bind()
        applyState()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Configure

    private func configure() {
        let hdr = makeHeaderRow()
        hdr.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hdr)

        trackStack.axis = .vertical
        trackStack.spacing = 4
        trackStack.distribution = .fillEqually
        trackStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(trackStack)

        for track in Tracks.all {
            trackStack.addArrangedSubview(makeTrackRow(track: track))
        }

        NSLayoutConstraint.activate([
            hdr.topAnchor.constraint(equalTo: topAnchor),
            hdr.leadingAnchor.constraint(equalTo: leadingAnchor),
            hdr.trailingAnchor.constraint(equalTo: trailingAnchor),
            hdr.heightAnchor.constraint(equalToConstant: 18),

            trackStack.topAnchor.constraint(equalTo: hdr.bottomAnchor, constant: 4),
            trackStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func makeHeaderRow() -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let corner = UIView()
        corner.backgroundColor = .clear
        corner.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(corner)

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.isUserInteractionEnabled = false   // header just follows; cells scroll
        scroll.tag = -1
        row.addSubview(scroll)
        headerScrollView = scroll

        let labelStack = UIStackView()
        labelStack.axis = .horizontal
        labelStack.distribution = .fillEqually
        labelStack.spacing = beatGap
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        for g in 0..<4 {
            let group = UIStackView(arrangedSubviews: Array(stepLabels[g*4..<g*4+4]))
            group.axis = .horizontal
            group.distribution = .fillEqually
            group.spacing = cellSpacing
            labelStack.addArrangedSubview(group)
        }
        scroll.addSubview(labelStack)

        let minGroupW = 4 * 28.0 + 3 * cellSpacing
        let minLabelW = 4 * minGroupW + 3 * beatGap
        NSLayoutConstraint.activate([
            corner.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            corner.topAnchor.constraint(equalTo: row.topAnchor),
            corner.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            corner.widthAnchor.constraint(equalToConstant: headerColumnWidth),

            scroll.leadingAnchor.constraint(equalTo: corner.trailingAnchor, constant: 4),
            scroll.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: row.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: row.bottomAnchor),

            labelStack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            labelStack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            labelStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            labelStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            labelStack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            labelStack.widthAnchor.constraint(greaterThanOrEqualToConstant: minLabelW),
            labelStack.widthAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.widthAnchor),
        ])
        return row
    }

    private var headerScrollView: UIScrollView!

    private func makeTrackRow(track: Track) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let header = TrackHeaderView(track: track)
        header.translatesAutoresizingMaskIntoConstraints = false
        header.delegate = self
        row.addSubview(header)

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.delegate = self
        scroll.alwaysBounceHorizontal = true
        scroll.tag = Tracks.all.firstIndex(where: { $0.id == track.id }) ?? 0
        row.addSubview(scroll)

        let cellStack = UIStackView()
        cellStack.axis = .horizontal
        cellStack.distribution = .fillEqually
        cellStack.spacing = beatGap
        cellStack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(cellStack)

        var cells: [CellButton] = []
        for g in 0..<4 {
            let group = UIStackView()
            group.axis = .horizontal
            group.distribution = .fillEqually
            group.spacing = cellSpacing
            for step in g*4..<g*4+4 {
                let cell = CellButton()
                cell.trackColor = track.color
                cell.accentColor = track.accent
                cell.isBeat = (step % 4 == 0)
                cell.accessibilityLabel = "\(track.name) step \(step + 1)"
                cell.tag = step
                cell.addTarget(self, action: #selector(cellTapped(_:)), for: .touchUpInside)
                cell.translatesAutoresizingMaskIntoConstraints = false
                group.addArrangedSubview(cell)
                cells.append(cell)
            }
            cellStack.addArrangedSubview(group)
        }

        let minGroupW = 4 * 28.0 + 3 * cellSpacing
        let minCellW = 4 * minGroupW + 3 * beatGap
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            header.topAnchor.constraint(equalTo: row.topAnchor),
            header.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            header.widthAnchor.constraint(equalToConstant: headerColumnWidth),

            scroll.leadingAnchor.constraint(equalTo: header.trailingAnchor, constant: 4),
            scroll.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: row.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: row.bottomAnchor),

            cellStack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            cellStack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            cellStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            cellStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            cellStack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            cellStack.widthAnchor.constraint(greaterThanOrEqualToConstant: minCellW),
            cellStack.widthAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.widthAnchor),
        ])

        rows.append(RowView(track: track, header: header, scrollView: scroll, cellStack: cellStack, cells: cells))
        return row
    }

    // MARK: - Binding

    private func bind() {
        store.changes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] section in
                guard let self else { return }
                switch section {
                case .pattern: self.syncPattern()
                case .load:
                    self.syncPattern()
                    self.syncMutes()
                    self.syncVolumes()
                case .step: self.syncPlayhead()
                case .mutes: self.syncMutes()
                case .volumes: self.syncVolumes()
                default: break
                }
            }
            .store(in: &cancellables)
    }

    private func applyState() {
        syncPattern()
        syncMutes()
        syncVolumes()
    }

    private func syncPattern() {
        for row in rows {
            let arr = store.rows[row.track.id] ?? []
            for (i, cell) in row.cells.enumerated() {
                cell.isOn = arr.indices.contains(i) ? arr[i] : false
            }
        }
    }

    private func syncPlayhead() {
        let active = store.activeStep
        for row in rows {
            for (i, cell) in row.cells.enumerated() {
                cell.isPlayhead = (i == active)
            }
        }
        for (i, label) in stepLabels.enumerated() {
            let isActive = (i == active)
            label.textColor = isActive ? Theme.accent : ((i % 4 == 0) ? Theme.text : Theme.textFaint)
        }
    }

    private func syncMutes() {
        for row in rows {
            let muted = store.mutes[row.track.id] ?? false
            row.header.setMuted(muted)
            UIView.animate(withDuration: 0.18) {
                row.scrollView.alpha = muted ? 0.28 : 1.0
            }
        }
    }

    private func syncVolumes() {
        for row in rows {
            row.header.setVolume(store.volumes[row.track.id] ?? 0.8)
        }
    }

    // MARK: - Cell tap

    @objc private func cellTapped(_ sender: CellButton) {
        guard let row = rows.first(where: { $0.cells.contains(sender) }) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        delegate?.sequencer(toggleStep: row.track.id, step: sender.tag)
    }

    // MARK: - TrackHeaderViewDelegate

    func trackHeaderDidTapPreview(_ track: Track) {
        engine.preview(trackId: track.id)
    }

    func trackHeaderDidToggleMute(_ track: Track) {
        store.toggleMute(trackId: track.id)
    }

    func trackHeaderDidChangeVolume(_ track: Track, value: Float) {
        store.setVolume(trackId: track.id, value: value)
        engine.setTrackGain(track.id, value)
    }

    // MARK: - Scroll sync

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !syncing else { return }
        syncing = true
        defer { syncing = false }
        let offset = scrollView.contentOffset
        if scrollView !== headerScrollView {
            headerScrollView.contentOffset = offset
        }
        for row in rows where row.scrollView !== scrollView {
            row.scrollView.contentOffset = offset
        }
    }
}
