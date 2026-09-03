import Foundation
import GuideCore
import Security

public struct KeychainTalkCredentialStore: TalkCredentialStoring, Sendable {
    private let service: String
    private let account: String

    public init(
        service: String = "com.serpcompany.guidecompanion.internal.openai",
        account: String = "talk-api-key"
    ) {
        self.service = service
        self.account = account
    }

    public func credential() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else { throw keychainFailure(status) }
        return value
    }

    public func saveCredential(_ credential: String) throws {
        let trimmed = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GuideFailure(stage: .guidance, message: "The OpenAI key is empty.", recovery: "Paste a tester-owned API key and save again.")
        }
        let valueData = Data(trimmed.utf8)
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: valueData] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw keychainFailure(updateStatus) }

        var insert = baseQuery
        insert[kSecValueData as String] = valueData
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(insert as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw keychainFailure(addStatus) }
    }

    public func deleteCredential() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw keychainFailure(status) }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func keychainFailure(_ status: OSStatus) -> GuideFailure {
        GuideFailure(
            stage: .guidance,
            message: "SERPy could not update the Talk credential in Keychain (\(status)).",
            recovery: "Unlock this Mac and try the Keychain action again."
        )
    }
}
