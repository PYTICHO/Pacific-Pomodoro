import Cocoa
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var isRunning = false
    private var isWorkPhase = true
    private var timeRemaining: Int = {
        let saved = UserDefaults.standard.integer(forKey: "timeRemaining")
        return saved == 0 ? 30 * 60 : saved
    }()
    
    
    private var selectedSound: String {
        get { UserDefaults.standard.string(forKey: "selectedSound") ?? "Ping" }
        set { UserDefaults.standard.set(newValue, forKey: "selectedSound") }
    }

    private var workDuration: Int {
        get {
            let saved = UserDefaults.standard.integer(forKey: "workDuration")
            return saved == 0 ? 30 * 60 : saved
        }
        set { UserDefaults.standard.set(newValue, forKey: "workDuration") }
    }

    private var workSlider: NSSlider!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)

        constructMenu()
        requestNotificationPermission()

        // Проверяем, есть ли сохранённое значение таймера
        let savedTime = UserDefaults.standard.integer(forKey: "timeRemaining")

        if savedTime > 0 {
            // 🔹 Есть сохранённое значение
            timeRemaining = savedTime
            workDuration = savedTime // синхронизируем слайдер
        } else {
            // 🔹 Нет сохранённого — ставим по умолчанию
            timeRemaining = workDuration
        }

        updateTitle()
    }


    // MARK: - Меню
    private func constructMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Start", action: #selector(startTimer), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Pause", action: #selector(pauseTimer), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Reset", action: #selector(resetTimer), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())

        // Work duration label
        let workLabel = NSMenuItem()
        let minutes = workDuration / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                workLabel.title = "Work duration: \(hours)h"
            } else {
                workLabel.title = "Work duration: \(hours)h \(remainingMinutes)m"
            }
        } else {
            workLabel.title = "Work duration: \(minutes) min"
        }
        menu.addItem(workLabel)

        // Центрированный слайдер для work
        workSlider = makeCenteredSlider(
            value: Double(workDuration / 60),
            min: 1,
            max: 90,
            action: #selector(workSliderChanged)
        )
        let workSliderItem = NSMenuItem()
        workSliderItem.view = workSlider.superview // помещаем контейнер с отступами
        menu.addItem(workSliderItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Звуки уведомлений
        let soundLabel = NSMenuItem()
        soundLabel.title = "Notification sound:"
        menu.addItem(soundLabel)

        // Выпадающий список звуков
        let soundMenu = NSMenu()

        // ✅ Добавляем пункт "Off" в начало списка
        let soundNames = ["Off", "Ping", "Pop", "Submarine", "Basso", "Tink", "Glass", "Hero"]

        for sound in soundNames {
            let item = NSMenuItem(title: sound, action: #selector(selectSound(_:)), keyEquivalent: "")
            item.target = self
            item.state = (sound == selectedSound) ? .on : .off
            soundMenu.addItem(item)
        }

        // Заголовок подменю = текущий выбранный звук
        let soundSubmenuItem = NSMenuItem(title: selectedSound, action: nil, keyEquivalent: "")
        soundSubmenuItem.submenu = soundMenu
        menu.addItem(soundSubmenuItem)
        
        
        // ✅ Кнопка выхода
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    // MARK: - Слайдеры
    private func makeCenteredSlider(value: Double, min: Double, max: Double, action: Selector) -> NSSlider {
        let slider = NSSlider(value: value, minValue: min, maxValue: max, target: self, action: action)
        slider.isContinuous = true
        slider.controlSize = .small
        slider.frame.size = NSSize(width: 180, height: 18)

        // Делаем контейнер с отступами
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 22))
        slider.frame.origin = CGPoint(x: (container.frame.width - slider.frame.width) / 2, y: 2)
        container.addSubview(slider)

        // Немного светлее трек, темнее фон
        slider.wantsLayer = true
        slider.layer?.cornerRadius = 2
        slider.layer?.backgroundColor = NSColor.clear.cgColor

        return slider
    }

    @objc private func workSliderChanged() {
        let minutes = Int(workSlider.doubleValue)
        workDuration = minutes * 60
        stopAndReset(to: workDuration)
        updateMenuLabels()
    }

    private func updateMenuLabels() {
        guard let menu = statusItem.menu else { return }

        let minutes = workDuration / 60
        let labelText: String

        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                labelText = "Work duration: \(hours)h"
            } else {
                labelText = "Work duration: \(hours)h \(remainingMinutes)m"
            }
        } else {
            labelText = "Work duration: \(minutes) min"
        }

        menu.item(at: 4)?.title = labelText
    }

    // MARK: - Таймер
    @objc private func startTimer() {
        guard !isRunning else { return }
        isRunning = true
        scheduleTick()
    }

    @objc private func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    @objc private func resetTimer() {
        stopAndReset(to: workDuration)
    }

    private func stopAndReset(to newValue: Int) {
        isRunning = false
        timer?.invalidate()
        timer = nil
        isWorkPhase = true
        timeRemaining = newValue
        updateTitle()
    }

    private func scheduleTick() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
    }

    @objc private func selectSound(_ sender: NSMenuItem) {
        // Снимаем галочки со всех пунктов
        if let menu = sender.menu {
            for item in menu.items {
                item.state = .off
            }
        }

        // Ставим галочку на выбранном
        sender.state = .on
        selectedSound = sender.title

        // 🔧 Обновляем заголовок родительского пункта меню
        if let parentItem = sender.parent {
            parentItem.title = selectedSound
        }

        // 🎵 Проигрываем звук, если это не "Off"
        if selectedSound != "Off" {
            NSSound(named: NSSound.Name(selectedSound))?.play()
        }
    }



    
    @objc private func tick() {
        guard isRunning else { return }

        if timeRemaining > 0 {
            timeRemaining -= 1
            updateTitle()
        } else {
            // Остановка таймера
            isRunning = false
            timer?.invalidate()
            timer = nil

            // Звук завершения
            if selectedSound != "Off" {
                NSSound(named: NSSound.Name(selectedSound))?.play()
            }


            // Уведомление
            notify(title: "Work session ended", body: "Time to take a break or start again.")

            // Открываем меню приложения
            
            if let button = statusItem.button {
                // Возвращаем фокус в статусбар, чтобы меню сразу видно было
                button.performClick(nil)
            }
            

            // Сброс времени
            timeRemaining = workDuration
            updateTitle()
        }
    }

    private func updateTitle() {
        let totalMinutes = timeRemaining / 60
        let seconds = timeRemaining % 60

        // Если больше часа — показываем "1:05:00", иначе "45:00"
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            statusItem.button?.title = String(format: "%01d:%02d:%02d", hours, minutes, seconds)
        } else {
            statusItem.button?.title = String(format: "%02d:%02d", totalMinutes, seconds)
        }
    }

    // MARK: - Уведомления
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        UserDefaults.standard.set(timeRemaining, forKey: "timeRemaining")
    }
}
